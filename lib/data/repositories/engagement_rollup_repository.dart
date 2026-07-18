import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../local/database_helper.dart';

/// Turns raw analytics events into one row per day, metric and target.
///
/// A single device produced 23,000 raw events in a day of testing, almost all
/// of them screen opens. Uploading each one buries the clinical data in both the
/// database and the sync traffic.
///
/// **Aggregating rather than sampling is deliberate.** Every figure the study
/// computes from analytics is a `COUNT`, a `SUM(value)` or a `DISTINCT date` —
/// there is no query anywhere that reads an individual event row. A daily
/// rollup therefore reproduces those numbers *exactly*, where sampling would
/// only estimate them. What is given up is per-event ordering, and nothing
/// reads that.
class EngagementRollupRepository {
  final _helper = DatabaseHelper();

  /// Namespace for deterministic ids. Fixed forever: changing it would make
  /// every previously-synced day look like a brand-new record.
  static const _namespace = '6f1a1d3e-9b7c-4c2a-8f5e-2b3c4d5e6f70';
  static const _uuid = Uuid();

  /// Events rolled up rather than sent individually.
  ///
  /// These are high-volume and carry little on their own — one screen open is
  /// not interesting; a week's count is.
  static const aggregatedTypes = {
    'screen_open',
    'screen_close',
    'feature_open',
    'help_open',
    'read_aloud',
  };

  /// Events that keep syncing raw.
  ///
  /// Low-volume and analytically rich: task completion rate needs the
  /// start/complete pairing, and an error is worth seeing individually with its
  /// own timestamp.
  static const rawTypes = {'app_open', 'task_start', 'task_complete', 'error'};

  /// Rebuilds rollups for every day that has aggregated events.
  ///
  /// Recomputed from scratch rather than incremented: the count for a day is
  /// absolute, so a day that is rebuilt and re-sent overwrites its server row
  /// instead of double-counting. That is what makes re-syncing an in-progress
  /// day safe.
  Future<int> rebuild({int lookbackDays = 30}) async {
    final db = await _helper.database;
    final since = DateTime.now()
        .subtract(Duration(days: lookbackDays))
        .millisecondsSinceEpoch;

    try {
      final rows = await db.rawQuery(
        '''
        SELECT date(ts / 1000, 'unixepoch', 'localtime') AS day,
               type, name,
               COUNT(*) AS c,
               SUM(value) AS total
        FROM analytics_events
        WHERE ts >= ? AND type IN (${List.filled(aggregatedTypes.length, '?').join(',')})
        GROUP BY day, type, name
        ''',
        [since, ...aggregatedTypes],
      );

      final batch = db.batch();

      for (final r in rows) {
        final day = r['day'] as String?;
        final type = r['type'] as String?;
        if (day == null || type == null) continue;

        final target = r['name'] as String?;

        // Deterministic id: the same day+metric+target always maps to the same
        // uuid, across app restarts and reinstalls of the queue, so the server
        // updates one row rather than accumulating a copy per sync.
        final localUuid = _uuid.v5(_namespace, '$day|$type|${target ?? ''}');

        batch.insert(
          'engagement_daily',
          {
            'local_uuid': localUuid,
            'day': day,
            'name': type,
            'target': target,
            'event_count': (r['c'] as int?) ?? 0,
            'total_value': r['total'] as int?,
            // Recomputed rows are queued again: the count has changed.
            'pending_sync': 1,
            'synced_at': null,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);

      return rows.length;
    } catch (e) {
      debugPrint('⚠️ engagement rollup failed: $e');
      return 0;
    }
  }

  /// Drops raw aggregated events once they are older than the rollup window.
  ///
  /// Their totals are already preserved in `engagement_daily`, so this frees the
  /// device without losing anything the study reads. Raw low-volume events are
  /// never pruned.
  Future<int> pruneOldRawEvents({int keepDays = 30}) async {
    final db = await _helper.database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: keepDays))
        .millisecondsSinceEpoch;

    try {
      return await db.delete(
        'analytics_events',
        where: 'ts < ? AND type IN (${List.filled(aggregatedTypes.length, '?').join(',')})',
        whereArgs: [cutoff, ...aggregatedTypes],
      );
    } catch (e) {
      debugPrint('⚠️ analytics prune failed: $e');
      return 0;
    }
  }
}
