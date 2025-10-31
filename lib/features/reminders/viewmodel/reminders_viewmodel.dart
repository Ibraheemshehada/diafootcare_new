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


class RemindersViewModel extends ChangeNotifier {
  DateTime _selectedDay = DateTime.now();
  final List<Reminder> _items = [
    Reminder(
      id: 'r2',
      time: const TimeOfDay(hour: 13, minute: 0),
      title: 'Wound Care',
      note: 'Care',
      weekdays: const [
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
        DateTime.saturday,
        DateTime.sunday,
      ],
    ),
  ];

  DateTime get selectedDay => _selectedDay;
  List<Reminder> get items => List.unmodifiable(_items);

  void selectDay(DateTime d) {
    _selectedDay = DateTime(d.year, d.month, d.day);
    notifyListeners();
  }

  void add(Reminder r) {
    _items.add(r);
    notifyListeners();
  }

  void toggle(String id, bool v) {
    final i = _items.indexWhere((e) => e.id == id);
    if (i != -1) {
      _items[i].enabled = v;
      notifyListeners();
    }
  }

  void remove(String id) {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
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

