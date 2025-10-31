// lib/data/repositories/notes_repository.dart
import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../models/note.dart';


class NotesRepository {
  final _helper = DatabaseHelper();

  Future<List<Note>> getAll() async {
    final Database db = await _helper.database;
    final rows = await db.query('notes', orderBy: 'date DESC');
    return rows.map((e) => Note.fromMap(e)).toList();
  }

  Future<List<Note>> getRecent(int limit) async {
    final db = await _helper.database;
    final rows = await db.query('notes', orderBy: 'date DESC', limit: limit);
    return rows.map((e) => Note.fromMap(e)).toList();
  }

  Future<List<Note>> getByDate(DateTime d) async {
    final db = await _helper.database;
    final start = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
    final end = DateTime(d.year, d.month, d.day).add(const Duration(days: 1)).millisecondsSinceEpoch;
    final rows = await db.query(
      'notes',
      where: 'date >= ? AND date < ?',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );
    return rows.map((e) => Note.fromMap(e)).toList();
  }

  Future<void> insert(Note note) async {
    final db = await _helper.database;
    await db.insert('notes', note.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(Note note) async {
    final db = await _helper.database;
    await db.update('notes', note.toMap(), where: 'id = ?', whereArgs: [note.id]);
  }

  Future<void> delete(String id) async {
    final db = await _helper.database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }
}
