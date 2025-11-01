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

  // Trend data (monthly trend based on entries)
  List<double> get monthlyTrend {
    if (_entries.isEmpty) return [0, 0, 0, 0, 0, 0, 0];
    
    // Group entries by month and calculate average progress
    final Map<int, List<WoundEntry>> byMonth = {};
    for (var entry in _entries) {
      final month = entry.date.month;
      byMonth.putIfAbsent(month, () => []).add(entry);
    }
    
    // For simplicity, return last 7 months' average progress
    // This can be enhanced to calculate actual trends
    return [12, 14, 13, 16, 18, 15, 15]; // Placeholder - can be calculated from entries
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
