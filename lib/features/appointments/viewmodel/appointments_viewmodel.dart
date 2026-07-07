import 'package:flutter/material.dart';

import '../../../data/models/appointment.dart';
import '../../../data/repositories/appointments_repository.dart';

class AppointmentsViewModel extends ChangeNotifier {
  final AppointmentsRepository _repo = AppointmentsRepository();

  List<Appointment> _items = [];
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  /// Future appointments, soonest first.
  List<Appointment> get upcoming =>
      _items.where((a) => !a.isPast).toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  /// Past appointments, most recent first.
  List<Appointment> get past =>
      _items.where((a) => a.isPast).toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

  /// The soonest upcoming appointment (for the Home dashboard), or null.
  Appointment? get nextUpcoming {
    final u = upcoming;
    return u.isEmpty ? null : u.first;
  }

  AppointmentsViewModel() {
    load();
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _items = await _repo.getAll();
      // Re-arm reminders for any future appointment (idempotent: same notif id).
      for (final a in _items.where((e) => !e.isPast)) {
        await _repo.scheduleReminder(a);
      }
    } catch (e) {
      debugPrint('❌ Error loading appointments: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> add({
    required String title,
    required DateTime dateTime,
    String location = '',
    String notes = '',
    required int reminderLead,
  }) async {
    final a = Appointment(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      dateTime: dateTime,
      location: location,
      notes: notes,
      reminderLead: reminderLead,
      createdAt: DateTime.now(),
    );
    _items = [..._items, a];
    notifyListeners();
    try {
      await _repo.insert(a);
      await _repo.scheduleReminder(a);
    } catch (e) {
      debugPrint('❌ Error saving appointment: $e');
    }
  }

  Future<void> remove(String id) async {
    Appointment? removed;
    for (final a in _items) {
      if (a.id == id) {
        removed = a;
        break;
      }
    }
    _items = _items.where((a) => a.id != id).toList();
    notifyListeners();
    try {
      await _repo.delete(id);
      if (removed != null) await _repo.cancelReminder(removed);
    } catch (e) {
      debugPrint('❌ Error deleting appointment: $e');
    }
  }
}
