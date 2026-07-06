import 'package:flutter/material.dart';

import '../../../data/models/glucose_reading.dart';
import '../../../data/repositories/glucose_repository.dart';

class GlucoseViewModel extends ChangeNotifier {
  final GlucoseRepository _repo = GlucoseRepository();

  List<GlucoseReading> _items = [];
  bool _isLoading = false;

  List<GlucoseReading> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  GlucoseReading? get latest => _items.isEmpty ? null : _items.first;

  /// Average of the last [n] readings (mg/dL), or null if none.
  double? get recentAverage {
    if (_items.isEmpty) return null;
    final recent = _items.take(7).toList();
    final sum = recent.fold<double>(0, (a, r) => a + r.value);
    return sum / recent.length;
  }

  GlucoseViewModel() {
    load();
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _items = await _repo.getAll();
    } catch (e) {
      debugPrint('❌ Error loading glucose: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> add({
    required double value,
    required String tag,
    DateTime? when,
  }) async {
    final reading = GlucoseReading(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      value: value,
      dateTime: when ?? DateTime.now(),
      tag: tag,
    );
    _items = [reading, ..._items]
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    notifyListeners();
    try {
      await _repo.insert(reading);
    } catch (e) {
      debugPrint('❌ Error saving glucose: $e');
    }
  }

  Future<void> remove(String id) async {
    _items = _items.where((r) => r.id != id).toList();
    notifyListeners();
    try {
      await _repo.delete(id);
    } catch (e) {
      debugPrint('❌ Error deleting glucose: $e');
    }
  }
}
