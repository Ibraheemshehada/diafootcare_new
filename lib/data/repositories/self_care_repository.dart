import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../models/self_care_task.dart';

class SelfCareRepository {
  final _helper = DatabaseHelper();

  /// Set of completed task keys for a given [dateKey] (yyyymmdd).
  Future<Set<String>> doneItemsForDate(String dateKey) async {
    final db = await _helper.database;
    final rows = await db.query('self_care_logs',
        columns: ['itemKey'], where: 'dateKey = ?', whereArgs: [dateKey]);
    return rows.map((e) => e['itemKey'] as String).toSet();
  }

  Future<void> setDone({
    required String itemKey,
    required String dateKey,
    required bool done,
  }) async {
    final db = await _helper.database;
    final key = selfCareLogKey(itemKey, dateKey);
    if (done) {
      await db.insert(
        'self_care_logs',
        {
          'logKey': key,
          'itemKey': itemKey,
          'dateKey': dateKey,
          'doneAt': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await db.delete('self_care_logs', where: 'logKey = ?', whereArgs: [key]);
    }
  }

  /// Map of dateKey -> completed-task count for the given [dateKeys].
  Future<Map<String, int>> completedCountByDate(List<String> dateKeys) async {
    if (dateKeys.isEmpty) return {};
    final db = await _helper.database;
    final placeholders = List.filled(dateKeys.length, '?').join(',');
    final rows = await db.rawQuery(
      'SELECT dateKey, COUNT(*) as c FROM self_care_logs '
      'WHERE dateKey IN ($placeholders) GROUP BY dateKey',
      dateKeys,
    );
    final map = <String, int>{};
    for (final r in rows) {
      map[r['dateKey'] as String] = (r['c'] as int?) ?? 0;
    }
    return map;
  }

  /// Total completed tasks whose dateKey falls in [dateKeys].
  Future<int> completedCountForDates(List<String> dateKeys) async {
    if (dateKeys.isEmpty) return 0;
    final db = await _helper.database;
    final placeholders = List.filled(dateKeys.length, '?').join(',');
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as c FROM self_care_logs WHERE dateKey IN ($placeholders)',
      dateKeys,
    );
    return (rows.first['c'] as int?) ?? 0;
  }
}
