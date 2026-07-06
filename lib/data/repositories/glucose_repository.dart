import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../models/glucose_reading.dart';

class GlucoseRepository {
  final _helper = DatabaseHelper();

  Future<List<GlucoseReading>> getAll() async {
    final Database db = await _helper.database;
    final rows = await db.query('glucose_readings', orderBy: 'dateTime DESC');
    // db.query returns a read-only list; map produces a fresh mutable list.
    return rows.map((e) => GlucoseReading.fromMap(e)).toList();
  }

  Future<List<GlucoseReading>> getRecent(int limit) async {
    final db = await _helper.database;
    final rows = await db.query('glucose_readings',
        orderBy: 'dateTime DESC', limit: limit);
    return rows.map((e) => GlucoseReading.fromMap(e)).toList();
  }

  Future<GlucoseReading?> getLatest() async {
    final list = await getRecent(1);
    return list.isEmpty ? null : list.first;
  }

  Future<void> insert(GlucoseReading r) async {
    final db = await _helper.database;
    await db.insert('glucose_readings', r.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    final db = await _helper.database;
    await db.delete('glucose_readings', where: 'id = ?', whereArgs: [id]);
  }
}
