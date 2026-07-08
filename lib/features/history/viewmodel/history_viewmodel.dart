import 'package:flutter/foundation.dart';
import '../../../data/models/wound_entry.dart';
import '../../../data/repositories/wounds_repository.dart';

/// Time granularity of the healing-trend chart.
enum TrendRange { daily, weekly, monthly }

/// A healing-trend series, oldest → newest. [values] are percent reductions of
/// the average wound area relative to the first recorded bucket; [bucketStarts]
/// holds the start instant of each bucket so the UI can label the X axis.
@immutable
class TrendSeries {
  final List<double> values;
  final List<DateTime> bucketStarts;
  const TrendSeries(this.values, this.bucketStarts);
  static const empty = TrendSeries([], []);
  bool get isEmpty => values.isEmpty;
}

/// Start of the bucket that [d] falls into, at granularity [r].
DateTime trendBucketStart(DateTime d, TrendRange r) {
  switch (r) {
    case TrendRange.daily:
      return DateTime(d.year, d.month, d.day);
    case TrendRange.weekly:
      // Week starts Monday.
      final day = DateTime(d.year, d.month, d.day);
      return day.subtract(Duration(days: day.weekday - DateTime.monday));
    case TrendRange.monthly:
      return DateTime(d.year, d.month);
  }
}

/// [steps] buckets before [b]. Uses calendar arithmetic (not Duration) so it
/// stays correct across DST transitions and varying month lengths.
DateTime trendStepBack(DateTime b, TrendRange r, int steps) {
  switch (r) {
    case TrendRange.daily:
      return DateTime(b.year, b.month, b.day - steps);
    case TrendRange.weekly:
      return DateTime(b.year, b.month, b.day - 7 * steps);
    case TrendRange.monthly:
      return DateTime(b.year, b.month - steps);
  }
}

/// Healing trend over the last [bucketCount] buckets at granularity [range]
/// (oldest → newest): percent reduction of the average wound area versus the
/// first recorded bucket. Buckets with no entries carry the previous value
/// forward. Empty when there are no entries, or when the baseline area is 0
/// (e.g. uncalibrated measurements), since percent change is undefined then.
///
/// Pure function — [now] is injectable so the bucketing can be unit tested.
TrendSeries computeTrend(
  List<WoundEntry> entries,
  TrendRange range, {
  DateTime? now,
  int bucketCount = 7,
}) {
  if (entries.isEmpty) return TrendSeries.empty;

  // Average wound area (cm²) per bucket.
  final Map<DateTime, List<double>> areasByBucket = {};
  for (final e in entries) {
    areasByBucket
        .putIfAbsent(trendBucketStart(e.date, range), () => [])
        .add(e.lengthCm * e.widthCm);
  }
  double avg(List<double> v) => v.reduce((a, b) => a + b) / v.length;
  double pctVs(double baseline, List<double> areas) =>
      (baseline - avg(areas)) / baseline * 100;

  final firstBucket =
      areasByBucket.keys.reduce((a, b) => a.isBefore(b) ? a : b);
  final baseline = avg(areasByBucket[firstBucket]!);
  if (baseline <= 0) return TrendSeries.empty;

  final nowBucket = trendBucketStart(now ?? DateTime.now(), range);
  final windowStart = trendStepBack(nowBucket, range, bucketCount - 1);

  // Seed the carry-forward with the most recent measurement *before* the
  // window, otherwise a wound last measured before the window would plot as
  // 0% improvement instead of the progress already achieved.
  double last = 0;
  final prior = areasByBucket.keys.where((k) => k.isBefore(windowStart));
  if (prior.isNotEmpty) {
    final latestPrior = prior.reduce((a, b) => a.isAfter(b) ? a : b);
    last = pctVs(baseline, areasByBucket[latestPrior]!);
  }

  final values = <double>[];
  final starts = <DateTime>[];
  for (int i = bucketCount - 1; i >= 0; i--) {
    final b = trendStepBack(nowBucket, range, i);
    final areas = areasByBucket[b];
    if (areas != null) last = pctVs(baseline, areas);
    values.add(last);
    starts.add(b);
  }
  return TrendSeries(values, starts);
}

class HistoryViewModel extends ChangeNotifier {
  final WoundsRepository _repo = WoundsRepository();

  List<WoundEntry> _entries = [];
  bool _isLoading = false;
  TrendRange _range = TrendRange.monthly;

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

  /// Selected granularity of the healing-trend chart.
  TrendRange get range => _range;
  void setRange(TrendRange r) {
    if (r == _range) return;
    _range = r;
    notifyListeners();
  }

  /// The healing trend at the currently selected [range].
  TrendSeries get trend => trendFor(_range);

  TrendSeries trendFor(TrendRange r) => computeTrend(_entries, r);

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
