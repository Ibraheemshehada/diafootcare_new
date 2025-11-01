import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/repositories/wounds_repository.dart';
import '../../../data/repositories/notes_repository.dart';
import '../../../data/repositories/reminders_repo.dart';

enum ExportFormat { pdf, csv, xlsx }

class ExportDataViewModel extends ChangeNotifier {
  // Datasets
  bool woundAI = true;
  bool glucose = false;
  bool notes = false;
  bool medication = true;
  bool reminders = false;

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

  Future<void> export(BuildContext context) async {
    isLoading = true;
    notifyListeners();

    try {
      String content = '';
      String fileName = '';

      // Generate file name with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      
      switch (format) {
        case ExportFormat.csv:
          content = await _generateCSV();
          fileName = 'health_records_$timestamp.csv';
          break;
        case ExportFormat.pdf:
          // PDF generation would require pdf package - using CSV for now
          content = await _generateCSV();
          fileName = 'health_records_$timestamp.csv';
          break;
        case ExportFormat.xlsx:
          // Excel generation would require excel package - using CSV for now
          content = await _generateCSV();
          fileName = 'health_records_$timestamp.csv';
          break;
      }

      // Save and share file
      if (kIsWeb) {
        // Web: download directly
        await _downloadFileWeb(fileName, content);
      } else {
        // Mobile: save to temp directory and share
        final file = await _saveFile(fileName, content);
        if (file != null) {
          await Share.shareXFiles([XFile(file.path)], text: 'Health Records Export');
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('export_completed'.tr()),
            backgroundColor: Colors.green,
          ),
        );
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

  bool isLoading = false;

  Future<String> _generateCSV() async {
    final buffer = StringBuffer();
    
    // CSV Header
    buffer.writeln('Health Records Export');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('');

    // Wound AI Analysis
    if (woundAI) {
      buffer.writeln('=== Wound Photos & AI Analysis ===');
      buffer.writeln('Date,Length (cm),Width (cm),Depth (cm),Tissue Type,Pus Level,Inflammation,Healing Progress (%)');
      
      try {
        final woundsRepo = WoundsRepository();
        final wounds = await woundsRepo.loadAllWounds();
        for (var wound in wounds) {
          buffer.writeln([
            wound.date.toIso8601String(),
            wound.lengthCm.toStringAsFixed(2),
            wound.widthCm.toStringAsFixed(2),
            wound.depthCm?.toStringAsFixed(2) ?? 'N/A',
            'N/A', // tissueType not in WoundEntry model
            'N/A', // pusLevel not in WoundEntry model
            wound.inflammation,
            wound.progressPct.toStringAsFixed(1),
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
          // note.date is already a DateTime object
          buffer.writeln([
            note.date.toIso8601String(),
            '"${note.text.replaceAll('"', '""')}"', // Escape quotes in CSV
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

    // Glucose (placeholder - not implemented yet)
    if (glucose) {
      buffer.writeln('=== Glucose Readings ===');
      buffer.writeln('Date,Reading (mg/dL)');
      buffer.writeln('(No glucose data available)');
      buffer.writeln('');
    }

    // Medication (placeholder - not implemented yet)
    if (medication) {
      buffer.writeln('=== Medication Log ===');
      buffer.writeln('Date,Medication,Dosage');
      buffer.writeln('(No medication data available)');
      buffer.writeln('');
    }

    return buffer.toString();
  }

  Future<File?> _saveFile(String fileName, String content) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(content);
      return file;
    } catch (e) {
      debugPrint('Error saving file: $e');
      return null;
    }
  }

  Future<void> _downloadFileWeb(String fileName, String content) async {
    // For web, create a download link
    // This requires html package and platform-specific implementation
    // For now, just show content (can be enhanced)
    debugPrint('Web download: $fileName (${content.length} bytes)');
  }
}
