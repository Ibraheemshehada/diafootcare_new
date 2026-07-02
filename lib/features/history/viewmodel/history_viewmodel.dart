import 'package:flutter/foundation.dart';
import '../../../data/models/wound_entry.dart';
import '../../../data/repositories/wounds_repository.dart';

class HistoryViewModel extends ChangeNotifier {
  final WoundsRepository _repo = WoundsRepository();
  
  List<WoundEntry> _entries = [];
  bool _isLoading = false;

  HistoryViewModel() {
    _loadWounds();
  }

  List<WoundEntry> get entries => List.unmodifiable(_entries);
  bool get isLoading => _isLoading;

  int get totalEntries => _entries.length;

  int get overallImprovementPct {
    if (_entries.isEmpty) return 0;
    // Calculate improvement based on latest vs oldest entry
    if (_entries.length < 2) return 0;
    final latest = _entries.first;
    final oldest = _entries.last;
    final latestArea = latest.lengthCm * latest.widthCm;
    final oldestArea = oldest.lengthCm * oldest.widthCm;
    if (oldestArea == 0) return 0;
    final improvement = ((oldestArea - latestArea) / oldestArea * 100).round();
    return improvement.clamp(0, 100);
  }

  String get inflammationTrend {
    if (_entries.length < 2) return "Stable";
    final recent = _entries.take(3).toList();
    final hasNone = recent.any((e) => e.inflammation == 'None');
    if (hasNone) return "Decreasing";
    return "Stable";
  }

  /// Monthly healing trend for the last 7 calendar months (oldest → newest):
  /// percent reduction of the average wound area vs the first recorded month.
  /// Months without entries carry the previous value. Empty when no entries.
  List<double> get monthlyTrend {
    if (_entries.isEmpty) return const [];

    // Average area (cm²) per calendar month, keyed by year*12+month.
    final Map<int, List<double>> areasByMonth = {};
    for (final e in _entries) {
      final key = e.date.year * 12 + e.date.month;
      areasByMonth.putIfAbsent(key, () => []).add(e.lengthCm * e.widthCm);
    }
    double avg(List<double> v) => v.reduce((a, b) => a + b) / v.length;

    final firstKey = areasByMonth.keys.reduce((a, b) => a < b ? a : b);
    final baseline = avg(areasByMonth[firstKey]!);
    if (baseline <= 0) return const [];

    final now = DateTime.now();
    final nowKey = now.year * 12 + now.month;
    final trend = <double>[];
    double last = 0;
    for (int key = nowKey - 6; key <= nowKey; key++) {
      final areas = areasByMonth[key];
      if (areas != null) {
        last = (baseline - avg(areas)) / baseline * 100;
      }
      trend.add(last);
    }
    return trend;
  }

  Future<void> _loadWounds() async {
    _isLoading = true;
    notifyListeners();

    try {
      _entries = await _repo.loadAllWounds();
      debugPrint('✅ Loaded ${_entries.length} wound entries from database');
    } catch (e) {
      debugPrint('❌ Error loading wounds: $e');
      _entries = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh wounds from database
  Future<void> refresh() async {
    await _loadWounds();
  }
}
