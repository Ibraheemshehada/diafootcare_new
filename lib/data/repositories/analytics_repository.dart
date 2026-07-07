import 'package:flutter/foundation.dart';

import '../local/database_helper.dart';
import '../models/analytics_summary.dart';

class AnalyticsRepository {
  final _helper = DatabaseHelper();

  /// Record one event. [type] is e.g. 'app_open' | 'feature_open'; [name] is the
  /// feature route for feature_open. Best-effort: never throws to the caller.
  Future<void> log(String type, [String? name]) async {
    try {
      final db = await _helper.database;
      await db.insert('analytics_events', {
        'type': type,
        'name': name,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('⚠️ analytics log failed: $e');
    }
  }

  Future<AnalyticsSummary> getSummary() async {
    try {
      final db = await _helper.database;

      final openRows = await db.rawQuery(
          "SELECT COUNT(*) c FROM analytics_events WHERE type = 'app_open'");
      final appOpens = (openRows.first['c'] as int?) ?? 0;

      final minMax = await db
          .rawQuery('SELECT MIN(ts) mn, MAX(ts) mx FROM analytics_events');
      final mn = minMax.first['mn'] as int?;
      final mx = minMax.first['mx'] as int?;

      final dayRows = await db.rawQuery(
          "SELECT DISTINCT date(ts / 1000, 'unixepoch', 'localtime') d "
          "FROM analytics_events ORDER BY d DESC");
      final days = dayRows.map((r) => r['d'] as String).toList();

      final featRows = await db.rawQuery(
          "SELECT name, COUNT(*) c FROM analytics_events "
          "WHERE type = 'feature_open' AND name IS NOT NULL "
          "GROUP BY name ORDER BY c DESC");
      final features = featRows
          .map((r) => FeatureCount(r['name'] as String, (r['c'] as int?) ?? 0))
          .toList();

      return AnalyticsSummary(
        appOpens: appOpens,
        activeDays: days.length,
        currentStreak: _streakFromDays(days.toSet()),
        firstUse: mn == null ? null : DateTime.fromMillisecondsSinceEpoch(mn),
        lastActive: mx == null ? null : DateTime.fromMillisecondsSinceEpoch(mx),
        features: features,
      );
    } catch (e) {
      debugPrint('⚠️ analytics summary failed: $e');
      return AnalyticsSummary.empty;
    }
  }

  String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Consecutive active days ending today (or yesterday if today has no
  /// activity yet). [activeDays] holds 'YYYY-MM-DD' keys.
  int _streakFromDays(Set<String> activeDays) {
    if (activeDays.isEmpty) return 0;
    var cursor = DateTime.now();
    if (!activeDays.contains(_dayKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!activeDays.contains(_dayKey(cursor))) return 0;
    }
    var streak = 0;
    while (activeDays.contains(_dayKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}
