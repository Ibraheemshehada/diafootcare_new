import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../models/medication.dart';

class MedicationRepository {
  final _helper = DatabaseHelper();

  Future<List<Medication>> getAll() async {
    final Database db = await _helper.database;
    final rows = await db.query('medications', orderBy: 'createdAt DESC');
    return rows.map((e) => Medication.fromMap(e)).toList();
  }

  Future<void> insert(Medication m) async {
    final db = await _helper.database;
    await db.insert('medications', m.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    final db = await _helper.database;
    await db.delete('medications', where: 'id = ?', whereArgs: [id]);
    await db
        .delete('medication_logs', where: 'medicationId = ?', whereArgs: [id]);
  }

  /// Set of taken dose keys for a given [dateKey] (yyyymmdd).
  Future<Set<String>> takenDoseKeys(String dateKey) async {
    final db = await _helper.database;
    final rows = await db.query('medication_logs',
        columns: ['doseKey'], where: 'dateKey = ?', whereArgs: [dateKey]);
    return rows.map((e) => e['doseKey'] as String).toSet();
  }

  Future<void> setDoseTaken({
    required String medicationId,
    required String dateKey,
    required int doseIndex,
    required bool taken,
  }) async {
    final db = await _helper.database;
    final key = Medication.doseKey(medicationId, dateKey, doseIndex);
    if (taken) {
      await db.insert(
        'medication_logs',
        {
          'doseKey': key,
          'medicationId': medicationId,
          'dateKey': dateKey,
          'doseIndex': doseIndex,
          'takenAt': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await db
          .delete('medication_logs', where: 'doseKey = ?', whereArgs: [key]);
    }
  }

  /// Number of taken doses whose dateKey falls in [dateKeys].
  Future<int> takenCountForDates(List<String> dateKeys) async {
    if (dateKeys.isEmpty) return 0;
    final db = await _helper.database;
    final placeholders = List.filled(dateKeys.length, '?').join(',');
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as c FROM medication_logs WHERE dateKey IN ($placeholders)',
      dateKeys,
    );
    return (rows.first['c'] as int?) ?? 0;
  }
}
