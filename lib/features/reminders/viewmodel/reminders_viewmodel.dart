// import 'package:flutter/material.dart';
//
// import '../../../data/models/reminder.dart';
//
// class RemindersViewModel extends ChangeNotifier {
//   DateTime _selectedDay = DateTime.now();
//   final List<Reminder> _items = [
//     Reminder(
//       id: 'r1',
//       time: const TimeOfDay(hour: 8, minute: 0),
//       title: 'Glucophage 500mg',
//       note: 'Medication',
//       weekdays: const [DateTime.monday, DateTime.wednesday, DateTime.friday],
//     ),
//     Reminder(
//       id: 'r2',
//       time: const TimeOfDay(hour: 13, minute: 0),
//       title: 'Wound Care',
//       note: 'Care',
//       weekdays: const [
//         DateTime.monday,
//         DateTime.tuesday,
//         DateTime.wednesday,
//         DateTime.thursday,
//         DateTime.friday,
//         DateTime.saturday,
//         DateTime.sunday,
//       ],
//     ),
//   ];
//
//   DateTime get selectedDay => _selectedDay;
//   List<Reminder> get items => List.unmodifiable(_items);
//
//   void selectDay(DateTime d) {
//     _selectedDay = DateTime(d.year, d.month, d.day);
//     notifyListeners();
//   }
//
//   void toggle(String id, bool v) {
//     final i = _items.indexWhere((e) => e.id == id);
//     if (i != -1) {
//       _items[i].enabled = v;
//       notifyListeners();
//     }
//   }
//
//   void remove(String id) {
//     _items.removeWhere((e) => e.id == id);
//     notifyListeners();
//   }
//
//   List<Reminder> remindersForSelectedDay() {
//     final wd = _selectedDay.weekday; // 1..7
//     return _items.where((r) => r.weekdays.contains(wd)).toList();
//   }
//
//   // int totalForSelectedDay() => remindersForSelectedDay().length;
//   int doneForSelectedDay() => 0; // hook up to completion state if needed later
//
//
//   // ✅ how many reminders are enabled (switch = ON) for the selected day
//   int enabledForSelectedDay() {
//     final wd = _selectedDay.weekday;
//     return _items.where((r) => r.weekdays.contains(wd) && r.enabled).length;
//   }
//
//   // ✅ total reminders for the selected day
//   int totalForSelectedDay() {
//     final wd = _selectedDay.weekday;
//     return _items.where((r) => r.weekdays.contains(wd)).length;
//   }
// }

import 'package:flutter/material.dart';

import '../../../data/models/reminder.dart';
import '../../../data/repositories/reminders_repo.dart';

class RemindersViewModel extends ChangeNotifier {
  DateTime _selectedDay = DateTime.now();
  List<Reminder> _items = [];
  final RemindersRepo _repo = RemindersRepo();
  bool _isLoading = false;

  RemindersViewModel() {
    _loadReminders();
  }

  DateTime get selectedDay => _selectedDay;
  List<Reminder> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;

  Future<void> _loadReminders() async {
    _isLoading = true;
    notifyListeners();
    try {
      _items = await _repo.load();
      // Reschedule all enabled reminders
      await _repo.rescheduleAll(_items);
    } catch (e) {
      debugPrint('Error loading reminders: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectDay(DateTime d) {
    _selectedDay = DateTime(d.year, d.month, d.day);
    notifyListeners();
  }

  Future<void> add(Reminder r) async {
    _items.add(r);
    notifyListeners();
    try {
      await _repo.save(_items);
      await _repo.schedule(r);
    } catch (e) {
      debugPrint('Error adding reminder: $e');
    }
  }

  Future<void> toggle(String id, bool v) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i != -1) {
      _items[i].enabled = v;
      notifyListeners();
      try {
        await _repo.save(_items);
        if (v) {
          await _repo.schedule(_items[i]);
        } else {
          await _repo.cancel(_items[i]);
        }
      } catch (e) {
        debugPrint('Error toggling reminder: $e');
      }
    }
  }

  Future<void> remove(String id) async {
    final reminderIndex = _items.indexWhere((e) => e.id == id);
    if (reminderIndex == -1) return;
    
    final reminder = _items[reminderIndex];
    _items.removeAt(reminderIndex);
    notifyListeners();
    try {
      await _repo.save(_items);
      await _repo.cancel(reminder);
    } catch (e) {
      debugPrint('Error removing reminder: $e');
    }
  }

  List<Reminder> remindersForSelectedDay() {
    final sel = _selectedDay;
    final wd = sel.weekday; // 1..7
    return _items.where((r) {
      if (r.oneOffDate != null) {
        final d = r.oneOffDate!;
        return d.year == sel.year && d.month == sel.month && d.day == sel.day;
      }
      return r.weekdays.contains(wd);
    }).toList();
  }

  int enabledForSelectedDay() {
    final sel = _selectedDay;
    final wd = sel.weekday;
    return _items.where((r) {
      if (r.oneOffDate != null) {
        final d = r.oneOffDate!;
        return r.enabled && d.year == sel.year && d.month == sel.month && d.day == sel.day;
      }
      return r.enabled && r.weekdays.contains(wd);
    }).length;
  }

  int totalForSelectedDay() => remindersForSelectedDay().length;
}

