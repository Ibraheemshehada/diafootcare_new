import 'package:flutter/material.dart';

import '../../../data/models/qol_entry.dart';
import '../../../data/repositories/wellbeing_repository.dart';

class WellbeingViewModel extends ChangeNotifier {
  final WellbeingRepository _repo = WellbeingRepository();

  List<QolEntry> _qol = []; // newest first
  List<SatisfactionEntry> _satisfaction = []; // newest first
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  List<QolEntry> get qolEntries => List.unmodifiable(_qol);
  QolEntry? get latestQol => _qol.isEmpty ? null : _qol.first;

  List<SatisfactionEntry> get satisfactionEntries =>
      List.unmodifiable(_satisfaction);
  SatisfactionEntry? get latestSatisfaction =>
      _satisfaction.isEmpty ? null : _satisfaction.first;

  /// Composite QoL burden series (oldest → newest) for the trend chart,
  /// limited to the most recent [max] entries.
  List<double> qolBurdenTrend({int max = 8}) {
    final chron = _qol.reversed.toList(); // oldest → newest
    final start = chron.length > max ? chron.length - max : 0;
    return chron.sublist(start).map((e) => e.burden).toList();
  }

  WellbeingViewModel() {
    load();
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _qol = await _repo.getAllQol();
      _satisfaction = await _repo.getAllSatisfaction();
    } catch (e) {
      debugPrint('❌ Error loading well-being data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addQol({
    required int pain,
    required int mobility,
    required int emotional,
  }) async {
    final e = QolEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      dateTime: DateTime.now(),
      pain: pain,
      mobility: mobility,
      emotional: emotional,
    );
    _qol = [e, ..._qol];
    notifyListeners();
    try {
      await _repo.insertQol(e);
    } catch (err) {
      debugPrint('❌ Error saving QoL entry: $err');
    }
  }

  Future<void> removeQol(String id) async {
    _qol = _qol.where((e) => e.id != id).toList();
    notifyListeners();
    try {
      await _repo.deleteQol(id);
    } catch (err) {
      debugPrint('❌ Error deleting QoL entry: $err');
    }
  }

  Future<void> addSatisfaction({
    required int ease,
    required int usefulness,
    required int willingness,
  }) async {
    final e = SatisfactionEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      dateTime: DateTime.now(),
      ease: ease,
      usefulness: usefulness,
      willingness: willingness,
    );
    _satisfaction = [e, ..._satisfaction];
    notifyListeners();
    try {
      await _repo.insertSatisfaction(e);
    } catch (err) {
      debugPrint('❌ Error saving satisfaction entry: $err');
    }
  }
}
