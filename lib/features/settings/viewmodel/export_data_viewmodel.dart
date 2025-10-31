import 'package:flutter/material.dart';

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

  Future<void> export() async {
    // TODO: implement real export (PDF/CSV/Excel)
    await Future<void>.delayed(const Duration(seconds: 1));
  }
}
