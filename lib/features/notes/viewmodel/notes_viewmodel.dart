import 'package:flutter/material.dart';
import '../../../data/models/note.dart';
import '../../../data/repositories/notes_repository.dart';

class NotesViewModel extends ChangeNotifier {
  NotesViewModel() {
    init(); // Load notes when ViewModel is created
  }

  final _repo = NotesRepository();

  DateTime _selected = DateTime.now();
  bool _loading = false;
  List<Note> _items = [];

  DateTime get selected => _selected;
  bool get loading => _loading;
  List<Note> get all => List.unmodifiable(
    List<Note>.from(_items)..sort((a, b) => b.date.compareTo(a.date)),
  );

  /// **Initialize and load data safely**
  Future<void> init() async {
    _loading = true;
    notifyListeners();
    try {
      _items = await _repo.getAll();

      // 🔍 Debug print each note
      if (_items.isEmpty) {
        debugPrint('🔍 Notes: No notes found in DB.');
      } else {
        for (final note in _items) {
          debugPrint('🔍 Note loaded -> ID: ${note.id}, Date: ${note.date}, Text: ${note.text}');
        }
      }
    } catch (e) {
      debugPrint('❌ Notes init error: $e');
      _items = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }


  void select(DateTime d) {
    _selected = DateTime(d.year, d.month, d.day);
    notifyListeners();
  }

  Future<List<Note>> byDate(DateTime d) => _repo.getByDate(d);

  List<Note> recent({int count = 8}) {
    final sorted = List<Note>.from(_items)
      ..sort((a, b) => b.date.compareTo(a.date));
    return sorted.take(count).toList();
  }

  Future<void> addNote({required DateTime date, required String text}) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final note = Note(
      id: id,
      date: DateTime(date.year, date.month, date.day),
      text: text.trim(),
    );

    await _repo.insert(note);
    _items.insert(0, note);
    debugPrint('✅ Note added -> ID: ${note.id}, Date: ${note.date}, Text: ${note.text}');
    notifyListeners();
  }

  Future<void> refresh() async {
    await init(); // Reload from DB
  }
}
