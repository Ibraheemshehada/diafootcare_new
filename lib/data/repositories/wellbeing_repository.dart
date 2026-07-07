import 'package:sqflite/sqflite.dart';

import '../local/database_helper.dart';
import '../models/qol_entry.dart';

class WellbeingRepository {
  final _helper = DatabaseHelper();

  // ---- Quality of Life ----
  Future<List<QolEntry>> getAllQol() async {
    final Database db = await _helper.database;
    final rows = await db.query('qol_entries', orderBy: 'dateTime DESC');
    return rows.map((e) => QolEntry.fromMap(e)).toList();
  }

  Future<void> insertQol(QolEntry e) async {
    final db = await _helper.database;
    await db.insert('qol_entries', e.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteQol(String id) async {
    final db = await _helper.database;
    await db.delete('qol_entries', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Satisfaction survey ----
  Future<List<SatisfactionEntry>> getAllSatisfaction() async {
    final db = await _helper.database;
    final rows =
        await db.query('satisfaction_entries', orderBy: 'dateTime DESC');
    return rows.map((e) => SatisfactionEntry.fromMap(e)).toList();
  }

  Future<void> insertSatisfaction(SatisfactionEntry e) async {
    final db = await _helper.database;
    await db.insert('satisfaction_entries', e.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSatisfaction(String id) async {
    final db = await _helper.database;
    await db.delete('satisfaction_entries', where: 'id = ?', whereArgs: [id]);
  }
}
