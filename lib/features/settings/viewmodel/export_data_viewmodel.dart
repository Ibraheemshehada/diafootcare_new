import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../data/repositories/wounds_repository.dart';
import '../../../data/repositories/notes_repository.dart';
import '../../../data/repositories/reminders_repo.dart';
import '../../../data/repositories/glucose_repository.dart';
import '../../../data/repositories/medication_repository.dart';
import '../../../data/models/medication.dart';
import '../../../data/repositories/self_care_repository.dart';
import '../../../data/models/self_care_task.dart';
import '../../../data/repositories/appointments_repository.dart';
import '../../../data/models/appointment.dart';
import '../../../data/repositories/wellbeing_repository.dart';
import '../../../data/repositories/analytics_repository.dart';
import '../../../core/services/analytics_service.dart';
import 'package:intl/intl.dart' as intl;

enum ExportFormat { pdf, csv, xlsx }

class ExportDataViewModel extends ChangeNotifier {
  // Datasets - defaults to true for all
  bool woundAI = true;
  bool glucose = false;
  bool notes = true;
  bool medication = false;
  bool selfCare = false;
  bool appointments = false;
  bool wellbeing = false;
  bool engagement = false;
  bool reminders = true;

  ExportFormat format = ExportFormat.pdf;

  bool get hasAny =>
      woundAI ||
      glucose ||
      notes ||
      medication ||
      selfCare ||
      appointments ||
      wellbeing ||
      engagement ||
      reminders;

  bool get allSelected =>
      woundAI &&
      glucose &&
      notes &&
      medication &&
      selfCare &&
      appointments &&
      wellbeing &&
      engagement &&
      reminders;

  void toggleAll(bool v) {
    woundAI = glucose = notes = medication =
        selfCare = appointments = wellbeing = engagement = reminders = v;
    notifyListeners();
  }

  void toggleWoundAI(bool v) { woundAI = v; notifyListeners(); }
  void toggleGlucose(bool v) { glucose = v; notifyListeners(); }
  void toggleNotes(bool v)   { notes = v; notifyListeners(); }
  void toggleMedication(bool v) { medication = v; notifyListeners(); }
  void toggleSelfCare(bool v) { selfCare = v; notifyListeners(); }
  void toggleAppointments(bool v) { appointments = v; notifyListeners(); }
  void toggleWellbeing(bool v) { wellbeing = v; notifyListeners(); }
  void toggleEngagement(bool v) { engagement = v; notifyListeners(); }
  void toggleReminders(bool v)  { reminders = v; notifyListeners(); }

  void setFormat(ExportFormat f) {
    if (format == f) return;
    format = f;
    notifyListeners();
  }

  bool isLoading = false;

  Future<void> export(BuildContext context) async {
    isLoading = true;
    notifyListeners();

    try {
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      String fileName;
      XFile? file;

      switch (format) {
        case ExportFormat.csv:
          final content = await _generateCSV();
          fileName = 'health_records_$timestamp.csv';
          file = await _saveTextFile(fileName, content);
          break;
        case ExportFormat.pdf:
          final pdfBytes = await _generatePDF();
          fileName = 'health_records_$timestamp.pdf';
          file = await _saveBinaryFile(fileName, pdfBytes);
          break;
        case ExportFormat.xlsx:
          final excelBytes = await _generateExcel();
          fileName = 'health_records_$timestamp.xlsx';
          file = await _saveBinaryFile(fileName, excelBytes);
          break;
      }

      if (file != null) {
        if (kIsWeb) {
          // Web: download directly
          await _downloadFileWeb(fileName, file.path);
        } else {
          // Mobile: share file
          await Share.shareXFiles([file], text: 'Health Records Export');
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('export_completed'.tr()),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to create export file');
      }
    } catch (e) {
      debugPrint('Export error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('export_failed'.tr() + ': $e')),
        );
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String> _generateCSV() async {
    final buffer = StringBuffer();
    
    buffer.writeln('Health Records Export');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('');

    if (woundAI) {
      buffer.writeln('=== Wound Photos & AI Analysis ===');
      buffer.writeln('Date,Length (cm),Width (cm),Depth (cm),Tissue Type,Pus Level,Inflammation,Healing Progress (%)');
      
      try {
        final woundsRepo = WoundsRepository();
        final wounds = await woundsRepo.loadAllWoundsForExport();
        for (var wound in wounds) {
          buffer.writeln([
            wound['date']?.toString() ?? '',
            (wound['length'] as num?)?.toStringAsFixed(2) ?? 'N/A',
            (wound['width'] as num?)?.toStringAsFixed(2) ?? 'N/A',
            (wound['depth'] as num?)?.toStringAsFixed(2) ?? 'N/A',
            wound['tissueType']?.toString() ?? 'N/A',
            wound['pusLevel']?.toString() ?? 'N/A',
            wound['inflammation']?.toString() ?? 'None',
            (wound['healingProgress'] as num?)?.toStringAsFixed(1) ?? '0.0',
          ].join(','));
        }
      } catch (e) {
        buffer.writeln('Error loading wounds: $e');
      }
      buffer.writeln('');
    }

    if (notes) {
      buffer.writeln('=== Daily Notes ===');
      buffer.writeln('Date,Note');
      
      try {
        final notesRepo = NotesRepository();
        final notesList = await notesRepo.getAll();
        for (var note in notesList) {
          buffer.writeln([
            note.date.toIso8601String(),
            '"${note.text.replaceAll('"', '""')}"',
          ].join(','));
        }
      } catch (e) {
        buffer.writeln('Error loading notes: $e');
      }
      buffer.writeln('');
    }

    if (reminders) {
      buffer.writeln('=== Reminders ===');
      buffer.writeln('Title,Time,Schedule,Note,Enabled');
      
      try {
        final remindersRepo = RemindersRepo();
        final remindersList = await remindersRepo.load();
        for (var reminder in remindersList) {
          String schedule = 'Custom';
          if (reminder.isOneOff()) {
            schedule = 'Once: ${reminder.oneOffDate?.toIso8601String() ?? 'N/A'}';
          } else if (reminder.repeatsDaily()) {
            schedule = 'Daily';
          } else {
            schedule = 'Weekly: ${reminder.weekdays.join(', ')}';
          }
          
          buffer.writeln([
            '"${reminder.title.replaceAll('"', '""')}"',
            '${reminder.time.hour.toString().padLeft(2, '0')}:${reminder.time.minute.toString().padLeft(2, '0')}',
            schedule,
            '"${reminder.note.replaceAll('"', '""')}"',
            reminder.enabled ? 'Yes' : 'No',
          ].join(','));
        }
      } catch (e) {
        buffer.writeln('Error loading reminders: $e');
      }
      buffer.writeln('');
    }

    if (glucose) {
      buffer.writeln('=== Glucose Readings ===');
      buffer.writeln('Date,Reading (mg/dL),Context,Status');
      try {
        final readings = await GlucoseRepository().getAll();
        if (readings.isEmpty) {
          buffer.writeln('(No glucose data available)');
        } else {
          for (final r in readings) {
            buffer.writeln([
              r.dateTime.toIso8601String(),
              r.value.toStringAsFixed(0),
              r.tag,
              r.status.name,
            ].join(','));
          }
        }
      } catch (e) {
        buffer.writeln('Error loading glucose: $e');
      }
      buffer.writeln('');
    }

    if (medication) {
      await _writeMedicationsCsv(buffer);
    }

    if (selfCare) {
      await _writeSelfCareCsv(buffer);
    }

    if (appointments) {
      await _writeAppointmentsCsv(buffer);
    }

    if (wellbeing) {
      await _writeWellbeingCsv(buffer);
    }

    if (engagement) {
      await _writeEngagementCsv(buffer);
    }

    return buffer.toString();
  }

  /// Shared CSV/Excel medication section: the medication list + a 7-day
  /// adherence figure (taken vs scheduled doses).
  Future<void> _writeMedicationsCsv(StringBuffer buffer) async {
    buffer.writeln('=== Medications ===');
    buffer.writeln('Medication,Dosage,Times per day');
    try {
      final repo = MedicationRepository();
      final meds = await repo.getAll();
      if (meds.isEmpty) {
        buffer.writeln('(No medication data available)');
      } else {
        for (final m in meds) {
          buffer.writeln([
            '"${m.name.replaceAll('"', '""')}"',
            '"${m.dosage.replaceAll('"', '""')}"',
            m.timesPerDay.toString(),
          ].join(','));
        }
        final now = DateTime.now();
        final keys = List.generate(
            7, (i) => medDateKey(now.subtract(Duration(days: i))));
        final taken = await repo.takenCountForDates(keys);
        final scheduled =
            meds.fold<int>(0, (a, m) => a + m.timesPerDay) * 7;
        final pct = scheduled == 0 ? 100 : ((taken / scheduled) * 100).round();
        buffer.writeln('');
        buffer.writeln('7-day adherence,$pct%,$taken/$scheduled doses');
      }
    } catch (e) {
      buffer.writeln('Error loading medications: $e');
    }
    buffer.writeln('');
  }

  /// Shared CSV/Excel self-care section: the tracked daily tasks + a 7-day
  /// adherence figure (completed vs scheduled tasks).
  Future<void> _writeSelfCareCsv(StringBuffer buffer) async {
    buffer.writeln('=== Self-Care Check-ins ===');
    buffer.writeln('Daily Task');
    try {
      for (final key in selfCareTaskKeys) {
        buffer.writeln('"${'selfcare_task_$key'.tr().replaceAll('"', '""')}"');
      }
      final repo = SelfCareRepository();
      final now = DateTime.now();
      final keys = List.generate(
          7, (i) => selfCareDateKey(now.subtract(Duration(days: i))));
      final completed = await repo.completedCountForDates(keys);
      final scheduled = selfCareTaskKeys.length * 7;
      final pct = scheduled == 0 ? 0 : ((completed / scheduled) * 100).round();
      buffer.writeln('');
      buffer.writeln('7-day adherence,$pct%,$completed/$scheduled tasks');
    } catch (e) {
      buffer.writeln('Error loading self-care: $e');
    }
    buffer.writeln('');
  }

  /// Shared CSV/Excel appointments section.
  Future<void> _writeAppointmentsCsv(StringBuffer buffer) async {
    buffer.writeln('=== Appointments ===');
    buffer.writeln('Title,Date & Time,Location,Reminder,Notes');
    try {
      final appts = await AppointmentsRepository().getAll();
      if (appts.isEmpty) {
        buffer.writeln('(No appointments available)');
      } else {
        for (final a in appts) {
          buffer.writeln([
            '"${a.title.replaceAll('"', '""')}"',
            intl.DateFormat('yyyy-MM-dd HH:mm').format(a.dateTime),
            '"${a.location.replaceAll('"', '""')}"',
            '"${appointmentLeadKey(a.reminderLead).tr()}"',
            '"${a.notes.replaceAll('"', '""')}"',
          ].join(','));
        }
      }
    } catch (e) {
      buffer.writeln('Error loading appointments: $e');
    }
    buffer.writeln('');
  }

  /// Shared CSV/Excel well-being section: QoL check-ins + satisfaction survey.
  Future<void> _writeWellbeingCsv(StringBuffer buffer) async {
    final repo = WellbeingRepository();

    buffer.writeln('=== Quality of Life (QoL) ===');
    buffer.writeln(
        'Date,Pain (0-10),Mobility difficulty (0-10),Emotional impact (0-10)');
    try {
      final entries = await repo.getAllQol();
      if (entries.isEmpty) {
        buffer.writeln('(No QoL check-ins available)');
      } else {
        for (final e in entries) {
          buffer.writeln([
            e.dateTime.toIso8601String(),
            e.pain.toString(),
            e.mobility.toString(),
            e.emotional.toString(),
          ].join(','));
        }
      }
    } catch (e) {
      buffer.writeln('Error loading QoL: $e');
    }
    buffer.writeln('');

    buffer.writeln('=== App Satisfaction ===');
    buffer.writeln(
        'Date,Ease of use (1-5),Usefulness (1-5),Willingness to continue (1-5)');
    try {
      final entries = await repo.getAllSatisfaction();
      if (entries.isEmpty) {
        buffer.writeln('(No satisfaction responses available)');
      } else {
        for (final e in entries) {
          buffer.writeln([
            e.dateTime.toIso8601String(),
            e.ease.toString(),
            e.usefulness.toString(),
            e.willingness.toString(),
          ].join(','));
        }
      }
    } catch (e) {
      buffer.writeln('Error loading satisfaction: $e');
    }
    buffer.writeln('');
  }

  /// Shared CSV/Excel engagement summary: usage metrics + per-feature opens.
  Future<void> _writeEngagementCsv(StringBuffer buffer) async {
    buffer.writeln('=== Engagement Summary ===');
    buffer.writeln('Metric,Value');
    try {
      final s = await AnalyticsRepository().getSummary();
      String fmt(DateTime? d) =>
          d == null ? 'N/A' : intl.DateFormat('yyyy-MM-dd').format(d);
      buffer.writeln('First used,${fmt(s.firstUse)}');
      buffer.writeln('Last active,${fmt(s.lastActive)}');
      buffer.writeln('Active days,${s.activeDays}');
      buffer.writeln('Current streak (days),${s.currentStreak}');
      buffer.writeln('App opens,${s.appOpens}');
      buffer.writeln('');
      buffer.writeln('Feature,Opens');
      if (s.features.isEmpty) {
        buffer.writeln('(No feature usage recorded)');
      } else {
        for (final f in s.features) {
          buffer.writeln([
            '"${analyticsFeatureLabel(f.route).replaceAll('"', '""')}"',
            f.count.toString(),
          ].join(','));
        }
      }
    } catch (e) {
      buffer.writeln('Error loading engagement: $e');
    }
    buffer.writeln('');
  }

  Future<Uint8List> _generatePDF() async {
    final pdf = pw.Document();
    
    // Build all sections first (await async data)
    final List<pw.Widget> allWidgets = [
      pw.Header(
        level: 0,
        child: pw.Text(
          'Health Records Export',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
      ),
      pw.SizedBox(height: 20),
      pw.Text(
        'Generated: ${DateTime.now().toIso8601String()}',
        style: const pw.TextStyle(fontSize: 10),
      ),
      pw.SizedBox(height: 30),
    ];
    
    // Wound AI Analysis
    if (woundAI) {
      allWidgets.addAll(await _buildWoundSection());
    }
    
    // Notes
    if (notes) {
      allWidgets.addAll(await _buildNotesSection());
    }
    
    // Reminders
    if (reminders) {
      allWidgets.addAll(await _buildRemindersSection());
    }
    
    // Glucose
    if (glucose) {
      allWidgets.addAll(await _buildGlucoseSection());
    }
    
    // Medication
    if (medication) {
      allWidgets.addAll(await _buildMedicationSection());
    }

    // Self-care
    if (selfCare) {
      allWidgets.addAll(await _buildSelfCareSection());
    }

    // Appointments
    if (appointments) {
      allWidgets.addAll(await _buildAppointmentsSection());
    }

    // Well-being (QoL + satisfaction)
    if (wellbeing) {
      allWidgets.addAll(await _buildWellbeingSection());
    }

    // Engagement summary
    if (engagement) {
      allWidgets.addAll(await _buildEngagementSection());
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) => allWidgets,
      ),
    );

    return await pdf.save();
  }

  Future<List<pw.Widget>> _buildWoundSection() async {
    final widgets = <pw.Widget>[];
    
    widgets.add(
      pw.Header(
        level: 1,
        child: pw.Text(
          'Wound Photos & AI Analysis',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
      ),
    );
    
    try {
      final woundsRepo = WoundsRepository();
      final wounds = await woundsRepo.loadAllWoundsForExport();
      
      if (wounds.isEmpty) {
        widgets.add(pw.Text('No wound analysis data available.'));
      } else {
        widgets.add(
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Length (cm)', 'Width (cm)', 'Depth (cm)', 'Tissue Type', 'Pus Level', 'Inflammation', 'Progress (%)'],
            data: wounds.map((w) => [
              w['date']?.toString().split('T')[0] ?? 'N/A',
              (w['length'] as num?)?.toStringAsFixed(2) ?? 'N/A',
              (w['width'] as num?)?.toStringAsFixed(2) ?? 'N/A',
              (w['depth'] as num?)?.toStringAsFixed(2) ?? 'N/A',
              w['tissueType']?.toString() ?? 'N/A',
              w['pusLevel']?.toString() ?? 'N/A',
              w['inflammation']?.toString() ?? 'None',
              (w['healingProgress'] as num?)?.toStringAsFixed(1) ?? '0.0',
            ]).toList(),
          ),
        );
      }
    } catch (e) {
      widgets.add(pw.Text('Error loading wounds: $e'));
    }
    
    widgets.add(pw.SizedBox(height: 20));
    return widgets;
  }

  Future<List<pw.Widget>> _buildNotesSection() async {
    final widgets = <pw.Widget>[];
    
    widgets.add(
      pw.Header(
        level: 1,
        child: pw.Text(
          'Daily Notes',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
      ),
    );
    
    try {
      final notesRepo = NotesRepository();
      final notesList = await notesRepo.getAll();
      
      if (notesList.isEmpty) {
        widgets.add(pw.Text('No notes available.'));
      } else {
        for (var note in notesList) {
          widgets.add(
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  note.date.toIso8601String().split('T')[0],
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(note.text),
                pw.SizedBox(height: 10),
              ],
            ),
          );
        }
      }
    } catch (e) {
      widgets.add(pw.Text('Error loading notes: $e'));
    }
    
    widgets.add(pw.SizedBox(height: 20));
    return widgets;
  }

  Future<List<pw.Widget>> _buildRemindersSection() async {
    final widgets = <pw.Widget>[];
    
    widgets.add(
      pw.Header(
        level: 1,
        child: pw.Text(
          'Reminders',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
      ),
    );
    
    try {
      final remindersRepo = RemindersRepo();
      final remindersList = await remindersRepo.load();
      
      if (remindersList.isEmpty) {
        widgets.add(pw.Text('No reminders available.'));
      } else {
        widgets.add(
          pw.TableHelper.fromTextArray(
            headers: ['Title', 'Time', 'Schedule', 'Note', 'Enabled'],
            data: remindersList.map((r) {
              String schedule = 'Custom';
              if (r.isOneOff()) {
                schedule = 'Once: ${r.oneOffDate?.toIso8601String().split('T')[0] ?? 'N/A'}';
              } else if (r.repeatsDaily()) {
                schedule = 'Daily';
              } else {
                schedule = 'Weekly: ${r.weekdays.join(', ')}';
              }
              
              return [
                r.title,
                '${r.time.hour.toString().padLeft(2, '0')}:${r.time.minute.toString().padLeft(2, '0')}',
                schedule,
                r.note,
                r.enabled ? 'Yes' : 'No',
              ];
            }).toList(),
          ),
        );
      }
    } catch (e) {
      widgets.add(pw.Text('Error loading reminders: $e'));
    }
    
    widgets.add(pw.SizedBox(height: 20));
    return widgets;
  }

  Future<List<pw.Widget>> _buildGlucoseSection() async {
    final widgets = <pw.Widget>[
      pw.Header(
        level: 1,
        child: pw.Text(
          'Glucose Readings',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
      ),
    ];
    try {
      final readings = await GlucoseRepository().getAll();
      if (readings.isEmpty) {
        widgets.add(pw.Text('No glucose data available.'));
      } else {
        widgets.add(
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Reading (mg/dL)', 'Context', 'Status'],
            data: readings
                .map((r) => [
                      r.dateTime.toIso8601String().split('T')[0] +
                          ' ' +
                          r.dateTime
                              .toIso8601String()
                              .split('T')[1]
                              .substring(0, 5),
                      r.value.toStringAsFixed(0),
                      r.tag,
                      r.status.name,
                    ])
                .toList(),
          ),
        );
      }
    } catch (e) {
      widgets.add(pw.Text('Error loading glucose: $e'));
    }
    widgets.add(pw.SizedBox(height: 20));
    return widgets;
  }

  Future<List<pw.Widget>> _buildMedicationSection() async {
    final widgets = <pw.Widget>[
      pw.Header(
        level: 1,
        child: pw.Text(
          'Medications',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
      ),
    ];
    try {
      final repo = MedicationRepository();
      final meds = await repo.getAll();
      if (meds.isEmpty) {
        widgets.add(pw.Text('No medication data available.'));
      } else {
        widgets.add(
          pw.TableHelper.fromTextArray(
            headers: ['Medication', 'Dosage', 'Times/day'],
            data: meds
                .map((m) => [m.name, m.dosage, m.timesPerDay.toString()])
                .toList(),
          ),
        );
        final now = DateTime.now();
        final keys = List.generate(
            7, (i) => medDateKey(now.subtract(Duration(days: i))));
        final taken = await repo.takenCountForDates(keys);
        final scheduled =
            meds.fold<int>(0, (a, m) => a + m.timesPerDay) * 7;
        final pct = scheduled == 0 ? 100 : ((taken / scheduled) * 100).round();
        widgets.add(pw.SizedBox(height: 8));
        widgets.add(pw.Text(
          '7-day adherence: $pct%  ($taken of $scheduled doses)',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ));
      }
    } catch (e) {
      widgets.add(pw.Text('Error loading medications: $e'));
    }
    widgets.add(pw.SizedBox(height: 20));
    return widgets;
  }

  Future<List<pw.Widget>> _buildSelfCareSection() async {
    final widgets = <pw.Widget>[
      pw.Header(
        level: 1,
        child: pw.Text(
          'Self-Care Check-ins',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
      ),
    ];
    try {
      widgets.add(
        pw.TableHelper.fromTextArray(
          headers: ['Daily Task'],
          data: selfCareTaskKeys
              .map((key) => [tr('selfcare_task_$key')])
              .toList(),
        ),
      );
      final repo = SelfCareRepository();
      final now = DateTime.now();
      final keys = List.generate(
          7, (i) => selfCareDateKey(now.subtract(Duration(days: i))));
      final completed = await repo.completedCountForDates(keys);
      final scheduled = selfCareTaskKeys.length * 7;
      final pct = scheduled == 0 ? 0 : ((completed / scheduled) * 100).round();
      widgets.add(pw.SizedBox(height: 8));
      widgets.add(pw.Text(
        '7-day adherence: $pct%  ($completed of $scheduled tasks)',
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      ));
    } catch (e) {
      widgets.add(pw.Text('Error loading self-care: $e'));
    }
    widgets.add(pw.SizedBox(height: 20));
    return widgets;
  }

  Future<List<pw.Widget>> _buildAppointmentsSection() async {
    final widgets = <pw.Widget>[
      pw.Header(
        level: 1,
        child: pw.Text(
          'Appointments',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
      ),
    ];
    try {
      final appts = await AppointmentsRepository().getAll();
      if (appts.isEmpty) {
        widgets.add(pw.Text('No appointments available.'));
      } else {
        widgets.add(
          pw.TableHelper.fromTextArray(
            headers: ['Title', 'Date & Time', 'Location', 'Reminder'],
            data: appts
                .map((a) => [
                      a.title,
                      intl.DateFormat('yyyy-MM-dd HH:mm').format(a.dateTime),
                      a.location,
                      appointmentLeadKey(a.reminderLead).tr(),
                    ])
                .toList(),
          ),
        );
      }
    } catch (e) {
      widgets.add(pw.Text('Error loading appointments: $e'));
    }
    widgets.add(pw.SizedBox(height: 20));
    return widgets;
  }

  Future<List<pw.Widget>> _buildWellbeingSection() async {
    final repo = WellbeingRepository();
    final widgets = <pw.Widget>[
      pw.Header(
        level: 1,
        child: pw.Text(
          'Quality of Life (QoL)',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
      ),
    ];
    try {
      final entries = await repo.getAllQol();
      if (entries.isEmpty) {
        widgets.add(pw.Text('No QoL check-ins available.'));
      } else {
        widgets.add(
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Pain', 'Mobility', 'Emotional'],
            data: entries
                .map((e) => [
                      e.dateTime.toIso8601String().split('T')[0],
                      e.pain.toString(),
                      e.mobility.toString(),
                      e.emotional.toString(),
                    ])
                .toList(),
          ),
        );
      }
    } catch (e) {
      widgets.add(pw.Text('Error loading QoL: $e'));
    }
    widgets.add(pw.SizedBox(height: 16));
    widgets.add(
      pw.Header(
        level: 1,
        child: pw.Text(
          'App Satisfaction',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
      ),
    );
    try {
      final entries = await repo.getAllSatisfaction();
      if (entries.isEmpty) {
        widgets.add(pw.Text('No satisfaction responses available.'));
      } else {
        widgets.add(
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Ease', 'Usefulness', 'Willingness'],
            data: entries
                .map((e) => [
                      e.dateTime.toIso8601String().split('T')[0],
                      e.ease.toString(),
                      e.usefulness.toString(),
                      e.willingness.toString(),
                    ])
                .toList(),
          ),
        );
      }
    } catch (e) {
      widgets.add(pw.Text('Error loading satisfaction: $e'));
    }
    widgets.add(pw.SizedBox(height: 20));
    return widgets;
  }

  Future<List<pw.Widget>> _buildEngagementSection() async {
    final widgets = <pw.Widget>[
      pw.Header(
        level: 1,
        child: pw.Text(
          'Engagement Summary',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
      ),
    ];
    try {
      final s = await AnalyticsRepository().getSummary();
      String fmt(DateTime? d) =>
          d == null ? 'N/A' : intl.DateFormat('yyyy-MM-dd').format(d);
      widgets.add(
        pw.TableHelper.fromTextArray(
          headers: ['Metric', 'Value'],
          data: [
            ['First used', fmt(s.firstUse)],
            ['Last active', fmt(s.lastActive)],
            ['Active days', s.activeDays.toString()],
            ['Current streak (days)', s.currentStreak.toString()],
            ['App opens', s.appOpens.toString()],
          ],
        ),
      );
      widgets.add(pw.SizedBox(height: 10));
      if (s.features.isNotEmpty) {
        widgets.add(
          pw.TableHelper.fromTextArray(
            headers: ['Feature', 'Opens'],
            data: s.features
                .map((f) =>
                    [analyticsFeatureLabel(f.route), f.count.toString()])
                .toList(),
          ),
        );
      }
    } catch (e) {
      widgets.add(pw.Text('Error loading engagement: $e'));
    }
    widgets.add(pw.SizedBox(height: 20));
    return widgets;
  }

  Future<Uint8List> _generateExcel() async {
    // Generate Excel-compatible CSV format (Excel can open CSV files)
    // This creates a CSV file with UTF-8 BOM that Excel can open properly
    final buffer = StringBuffer();
    
    // Add UTF-8 BOM for Excel compatibility
    buffer.write('\uFEFF');
    
    // Wound AI Analysis
    if (woundAI) {
      buffer.writeln('=== Wound Analysis ===');
      buffer.writeln('Date,Length (cm),Width (cm),Depth (cm),Tissue Type,Pus Level,Inflammation,Healing Progress (%)');
      
      try {
        final woundsRepo = WoundsRepository();
        final wounds = await woundsRepo.loadAllWoundsForExport();
        for (var wound in wounds) {
          buffer.writeln([
            wound['date']?.toString().split('T')[0] ?? '',
            (wound['length'] as num?)?.toStringAsFixed(2) ?? 'N/A',
            (wound['width'] as num?)?.toStringAsFixed(2) ?? 'N/A',
            (wound['depth'] as num?)?.toStringAsFixed(2) ?? 'N/A',
            wound['tissueType']?.toString() ?? 'N/A',
            wound['pusLevel']?.toString() ?? 'N/A',
            wound['inflammation']?.toString() ?? 'None',
            (wound['healingProgress'] as num?)?.toStringAsFixed(1) ?? '0.0',
          ].join(','));
        }
      } catch (e) {
        buffer.writeln('Error loading wounds: $e');
      }
      buffer.writeln('');
    }

    // Glucose
    if (glucose) {
      buffer.writeln('=== Glucose Readings ===');
      buffer.writeln('Date,Reading (mg/dL),Context,Status');
      try {
        final readings = await GlucoseRepository().getAll();
        if (readings.isEmpty) {
          buffer.writeln('(No glucose data available)');
        } else {
          for (final r in readings) {
            buffer.writeln([
              r.dateTime.toIso8601String(),
              r.value.toStringAsFixed(0),
              r.tag,
              r.status.name,
            ].join(','));
          }
        }
      } catch (e) {
        buffer.writeln('Error loading glucose: $e');
      }
      buffer.writeln('');
    }

    // Notes
    if (notes) {
      buffer.writeln('=== Daily Notes ===');
      buffer.writeln('Date,Note');

      try {
        final notesRepo = NotesRepository();
        final notesList = await notesRepo.getAll();
        for (var note in notesList) {
          buffer.writeln([
            note.date.toIso8601String().split('T')[0],
            '"${note.text.replaceAll('"', '""')}"',
          ].join(','));
        }
      } catch (e) {
        buffer.writeln('Error loading notes: $e');
      }
      buffer.writeln('');
    }

    // Reminders
    if (reminders) {
      buffer.writeln('=== Reminders ===');
      buffer.writeln('Title,Time,Schedule,Note,Enabled');
      
      try {
        final remindersRepo = RemindersRepo();
        final remindersList = await remindersRepo.load();
        for (var reminder in remindersList) {
          String schedule = 'Custom';
          if (reminder.isOneOff()) {
            schedule = 'Once: ${reminder.oneOffDate?.toIso8601String().split('T')[0] ?? 'N/A'}';
          } else if (reminder.repeatsDaily()) {
            schedule = 'Daily';
          } else {
            schedule = 'Weekly: ${reminder.weekdays.join(', ')}';
          }
          
          buffer.writeln([
            '"${reminder.title.replaceAll('"', '""')}"',
            '${reminder.time.hour.toString().padLeft(2, '0')}:${reminder.time.minute.toString().padLeft(2, '0')}',
            schedule,
            '"${reminder.note.replaceAll('"', '""')}"',
            reminder.enabled ? 'Yes' : 'No',
          ].join(','));
        }
      } catch (e) {
        buffer.writeln('Error loading reminders: $e');
      }
      buffer.writeln('');
    }

    // Medications
    if (medication) {
      await _writeMedicationsCsv(buffer);
    }

    // Self-care
    if (selfCare) {
      await _writeSelfCareCsv(buffer);
    }

    // Appointments
    if (appointments) {
      await _writeAppointmentsCsv(buffer);
    }

    // Well-being
    if (wellbeing) {
      await _writeWellbeingCsv(buffer);
    }

    // Engagement
    if (engagement) {
      await _writeEngagementCsv(buffer);
    }

    // Convert to UTF-8 bytes with BOM
    final content = buffer.toString();
    final utf8Bytes = utf8.encode(content);
    final bom = [0xEF, 0xBB, 0xBF]; // UTF-8 BOM
    return Uint8List.fromList([...bom, ...utf8Bytes]);
  }

  Future<XFile?> _saveTextFile(String fileName, String content) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(content);
      return XFile(file.path);
    } catch (e) {
      debugPrint('Error saving text file: $e');
      return null;
    }
  }

  Future<XFile?> _saveBinaryFile(String fileName, Uint8List bytes) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);
      return XFile(file.path);
    } catch (e) {
      debugPrint('Error saving binary file: $e');
      return null;
    }
  }

  Future<void> _downloadFileWeb(String fileName, String filePath) async {
    debugPrint('Web download: $fileName');
    // Web download would need html package for proper implementation
  }
}
