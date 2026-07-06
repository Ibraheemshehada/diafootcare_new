import 'package:flutter/material.dart';

import '../../../data/models/medication.dart';
import '../../../data/repositories/medication_repository.dart';

class MedicationViewModel extends ChangeNotifier {
  final MedicationRepository _repo = MedicationRepository();

  List<Medication> _items = [];
  Set<String> _takenToday = {};
  bool _isLoading = false;

  List<Medication> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;

  String get _todayKey => medDateKey(DateTime.now());

  /// Doses scheduled today across all medications.
  int get scheduledToday =>
      _items.fold(0, (a, m) => a + m.timesPerDay);

  /// Doses marked taken today.
  int get takenToday => _takenToday.length;

  /// Today's adherence 0..100 (100 if nothing scheduled).
  int get adherenceTodayPct {
    final s = scheduledToday;
    if (s == 0) return 100;
    return ((takenToday / s) * 100).round().clamp(0, 100);
  }

  bool isDoseTaken(String medicationId, int doseIndex) =>
      _takenToday.contains(Medication.doseKey(medicationId, _todayKey, doseIndex));

  MedicationViewModel() {
    load();
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _items = await _repo.getAll();
      _takenToday = await _repo.takenDoseKeys(_todayKey);
    } catch (e) {
      debugPrint('❌ Error loading medications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addMedication({
    required String name,
    required String dosage,
    required int timesPerDay,
  }) async {
    final med = Medication(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      dosage: dosage,
      timesPerDay: timesPerDay,
      createdAt: DateTime.now(),
    );
    _items = [med, ..._items];
    notifyListeners();
    try {
      await _repo.insert(med);
    } catch (e) {
      debugPrint('❌ Error saving medication: $e');
    }
  }

  Future<void> removeMedication(String id) async {
    _items = _items.where((m) => m.id != id).toList();
    _takenToday = _takenToday
        .where((k) => !k.startsWith('$id|'))
        .toSet();
    notifyListeners();
    try {
      await _repo.delete(id);
    } catch (e) {
      debugPrint('❌ Error deleting medication: $e');
    }
  }

  Future<void> toggleDose(String medicationId, int doseIndex) async {
    final key = Medication.doseKey(medicationId, _todayKey, doseIndex);
    final currentlyTaken = _takenToday.contains(key);
    if (currentlyTaken) {
      _takenToday.remove(key);
    } else {
      _takenToday.add(key);
    }
    notifyListeners();
    try {
      await _repo.setDoseTaken(
        medicationId: medicationId,
        dateKey: _todayKey,
        doseIndex: doseIndex,
        taken: !currentlyTaken,
      );
    } catch (e) {
      debugPrint('❌ Error toggling dose: $e');
    }
  }
}
