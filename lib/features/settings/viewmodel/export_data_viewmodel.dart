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

enum ExportFormat { pdf, csv, xlsx }

class ExportDataViewModel extends ChangeNotifier {
  // Datasets - defaults to true for all
  bool woundAI = true;
  bool glucose = false;
  bool notes = true;
  bool medication = false;
  bool reminders = true;

  ExportFormat format = ExportFormat.pdf;

  bool get hasAny =>
      woundAI || glucose || notes || medication || reminders;

  bool get allSelected =>
      woundAI && glucose && notes && medication && reminders;

  void toggleAll(bool v) {
    woundAI = glucose = notes = medication = reminders = v;
    notifyListeners();
  }

  void toggleWoundAI(bool v) { woundAI = v; notifyListeners(); }
  void toggleGlucose(bool v) { glucose = v; notifyListeners(); }
  void toggleNotes(bool v)   { notes = v; notifyListeners(); }
  void toggleMedication(bool v) { medication = v; notifyListeners(); }
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
      buffer.writeln('Date,Reading (mg/dL)');
      buffer.writeln('(No glucose data available)');
      buffer.writeln('');
    }

    if (medication) {
      buffer.writeln('=== Medication Log ===');
      buffer.writeln('Date,Medication,Dosage');
      buffer.writeln('(No medication data available)');
      buffer.writeln('');
    }

    return buffer.toString();
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
      allWidgets.addAll(_buildGlucoseSection());
    }
    
    // Medication
    if (medication) {
      allWidgets.addAll(_buildMedicationSection());
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

  List<pw.Widget> _buildGlucoseSection() {
    return [
      pw.Header(
        level: 1,
        child: pw.Text(
          'Glucose Readings',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
      ),
      pw.Text('(No glucose data available)'),
      pw.SizedBox(height: 20),
    ];
  }

  List<pw.Widget> _buildMedicationSection() {
    return [
      pw.Header(
        level: 1,
        child: pw.Text(
          'Medication Log',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
      ),
      pw.Text('(No medication data available)'),
      pw.SizedBox(height: 20),
    ];
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
