import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/notification_service.dart';
import '../models/reminder.dart';

class RemindersRepo {
  static const _k = 'reminders_v1';
  final _notifs = NotificationService.I;

  Future<List<Reminder>> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getStringList(_k) ?? const [];
      return raw.map((s) => Reminder.fromJson(jsonDecode(s))).toList();
    } catch (e) {
      debugPrint('Reminders load error: $e');
      return [];
    }
  }

  Future<void> save(List<Reminder> items) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(
      _k,
      items.map((r) => jsonEncode(r.toJson())).toList(),
    );
  }

  /// Rebuild all OS schedules from scratch (idempotent).
  Future<void> rescheduleAll(List<Reminder> items) async {
    await _notifs.init();
    await _notifs.cancelAll();

    for (final r in items.where((r) => r.enabled)) {
      await _scheduleOne(r);
    }
  }

  Future<void> schedule(Reminder r) async {
    await _notifs.init();
    if (!r.enabled) {
      debugPrint('⏰ Reminder ${r.id} is disabled, skipping schedule');
      return;
    }
    debugPrint('⏰ Scheduling reminder: ${r.title} at ${r.time.hour}:${r.time.minute}');
    await _scheduleOne(r);
    debugPrint('✅ Reminder scheduled successfully');
  }

  Future<void> cancel(Reminder r) async {
    await _notifs.init();
    final base = _notifs.notifIdFromKey(r.id);
    await _notifs.cancel(base);
    if (!r.isOneOff()) {
      await _notifs.cancelWeeklyChildren(base, r.weekdays);
    }
  }

  Future<void> _scheduleOne(Reminder r) async {
    try {
      final base = _notifs.notifIdFromKey(r.id);
      final body = r.note;

      debugPrint('📅 Reminder type: oneOff=${r.isOneOff()}, daily=${r.repeatsDaily()}, weekdays=${r.weekdays}');

      if (r.isOneOff()) {
        final d = r.oneOffDate!;
        final dt = DateTime(d.year, d.month, d.day, r.time.hour, r.time.minute);
        debugPrint('⏰ Scheduling one-off notification for: ${dt.toString()}');
        await _notifs.scheduleOneOff(
          id: base,
          title: r.title,
          body: body,
          whenLocal: dt,
        );
        debugPrint('✅ One-off notification scheduled');
        return;
      }

      if (r.repeatsDaily()) {
        debugPrint('⏰ Scheduling daily notification at ${r.time.hour}:${r.time.minute}');
        await _notifs.scheduleDaily(
          id: base,
          title: r.title,
          body: body,
          hour: r.time.hour,
          minute: r.time.minute,
        );
        debugPrint('✅ Daily notification scheduled');
        return;
      }

      // custom weekdays
      debugPrint('⏰ Scheduling weekly notification on ${r.weekdays} at ${r.time.hour}:${r.time.minute}');
      await _notifs.scheduleWeekly(
        baseId: base,
        title: r.title,
        body: body,
        hour: r.time.hour,
        minute: r.time.minute,
        weekdays: r.weekdays..sort(),
      );
      debugPrint('✅ Weekly notification scheduled');
    } catch (e, stackTrace) {
      debugPrint('❌ Error scheduling reminder: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
