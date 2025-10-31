import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;


final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

/// ✅ هذه الدالة سيتم استدعاؤها من AlarmManager حتى لو التطبيق مغلق
void showReminderNotification(int id, String title, String body) async {
  tz.initializeTimeZones();

  const android = AndroidNotificationDetails(
    'reminders_channel',
    'Reminders',
    importance: Importance.max,
    priority: Priority.max,
  );
  const iOS = DarwinNotificationDetails();

  await flutterLocalNotificationsPlugin.show(
    id,
    title,
    body,
    const NotificationDetails(android: android, iOS: iOS),
  );
}

/// One place to init, schedule, cancel notifications.
class NotificationService {
  NotificationService._();
  static final NotificationService I = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// MUST be called once (e.g., in main()).
  Future<void> init() async {
    if (_ready) return;

    // ✅ Initialize tz database
    tz.initializeTimeZones();

    // ✅ Use a valid, real timezone name
    // For Gaza, Jerusalem, or nearby regions, use 'Asia/Jerusalem'
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Jerusalem'));
    } catch (e) {
      // Fallback to UTC if anything goes wrong
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    if (!kIsWeb && Platform.isAndroid) {
      const AndroidNotificationChannel ch = AndroidNotificationChannel(
        'reminders_channel',
        'Reminders',
        description: 'DiaFootCare reminders',
        importance: Importance.max,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(ch);
    }

    _ready = true;
  }

  /// Map your string id to a stable int for the system.
  int notifIdFromKey(String key) => key.hashCode & 0x7fffffff;

  Future<void> cancel(int id) async {
    if (!_ready) return;
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }

  /// Schedule a one-off notification at a specific local DateTime.
  Future<void> scheduleOneOff({
    required int id,
    required String title,
    required String body,
    required DateTime whenLocal,
  }) async {
    if (!_ready) return;
    final zdt = tz.TZDateTime.from(whenLocal, tz.local);
    if (zdt.isBefore(tz.TZDateTime.now(tz.local))) return; // don’t schedule past

    final details = NotificationDetails(
      android: const AndroidNotificationDetails(
        'reminders_channel',
        'Reminders',
        priority: Priority.max,
        importance: Importance.max,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      zdt,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'reminder:$id',
    );
  }

  /// Schedule a **daily** notification at [hour:minute] local.
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    if (!_ready) return;
    final details = NotificationDetails(
      android: const AndroidNotificationDetails(
          'reminders_channel', 'Reminders',
          priority: Priority.max, importance: Importance.max),
      iOS: const DarwinNotificationDetails(),
    );

    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (next.isBefore(now)) next = next.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      next,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // daily at time
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'reminder:$id',
    );
  }

  /// Schedule multiple **weekly** notifications on given weekdays (1=Mon..7=Sun)
  Future<void> scheduleWeekly({
    required int baseId,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required List<int> weekdays, // 1..7
  }) async {
    if (!_ready) return;
    for (final w in weekdays) {
      final id = _subId(baseId, w); // stable child id per weekday
      await cancel(id); // replace if existed

      final details = NotificationDetails(
        android: const AndroidNotificationDetails(
            'reminders_channel', 'Reminders',
            priority: Priority.max, importance: Importance.max),
        iOS: const DarwinNotificationDetails(),
      );

      final now = tz.TZDateTime.now(tz.local);
      // Find next occurrence of weekday w at hour:minute
      var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      while (_weekdayIso(next.weekday) != w || next.isBefore(now)) {
        next = next.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        next,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'reminder:$baseId:$w',
      );
    }
  }

  /// Cancel children created by scheduleWeekly.
  Future<void> cancelWeeklyChildren(int baseId, List<int> weekdays) async {
    for (final w in weekdays) {
      await cancel(_subId(baseId, w));
    }
  }

  int _subId(int base, int weekdayIso) {
    // mix in weekday to keep ids unique and stable
    return ((base & 0x00FFFFFF) << 3) ^ weekdayIso;
  }

  int _weekdayIso(int dartWeekday) => dartWeekday; // already ISO 1..7
}



