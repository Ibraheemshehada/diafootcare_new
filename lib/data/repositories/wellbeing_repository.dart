import 'package:sqflite/sqflite.dart';

import '../local/database_helper.dart';
import '../models/consent_record.dart';
import '../models/qol_entry.dart';
import '../models/sus_entry.dart';

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

  // ---- System Usability Scale (SUS) ----
  Future<List<SusEntry>> getAllSus() async {
    final db = await _helper.database;
    final rows = await db.query('sus_responses', orderBy: 'dateTime DESC');
    return rows.map((e) => SusEntry.fromMap(e)).toList();
  }

  /// Stores a SUS response, stamped with the consent version in force when it
  /// was given. The stamp is what lets the study separate responses collected
  /// under the on-device-only declaration from those collected under the
  /// data-sharing one.
  Future<void> insertSus(SusEntry e) async {
    final db = await _helper.database;
    await db.insert(
      'sus_responses',
      {...e.toMap(), 'consent_version': kCurrentConsentVersion},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSus(String id) async {
    final db = await _helper.database;
    await db.delete('sus_responses', where: 'id = ?', whereArgs: [id]);
  }
}
