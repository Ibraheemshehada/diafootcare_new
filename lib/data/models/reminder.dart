import 'package:flutter/material.dart';

class Reminder {
  final String id;
  final TimeOfDay time;
  final String title;
  final String note;
  final List<int> weekdays;   // 1..7, empty if one-off
  final DateTime? oneOffDate; // local date only (00:00)
  bool enabled;

  Reminder({
    required this.id,
    required this.time,
    required this.title,
    required this.note,
    required this.weekdays,
    this.oneOffDate,
    this.enabled = true,
  });

  bool repeatsDaily() => oneOffDate == null && weekdays.length == 7;
  bool isOneOff() => oneOffDate != null;

  factory Reminder.fromJson(Map<String, dynamic> m) => Reminder(
    id: m['id'] as String,
    time: TimeOfDay(hour: m['h'] as int, minute: m['m'] as int),
    title: m['title'] as String,
    note: m['note'] as String,
    weekdays: (m['wd'] as List).cast<int>(),
    oneOffDate:
    m['od'] == null ? null : DateTime.parse(m['od'] as String),
    enabled: (m['en'] as bool?) ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'h': time.hour,
    'm': time.minute,
    'title': title,
    'note': note,
    'wd': weekdays,
    'od': oneOffDate == null
        ? null
        : DateTime(oneOffDate!.year, oneOffDate!.month, oneOffDate!.day)
        .toIso8601String(),
    'en': enabled,
  };
}
