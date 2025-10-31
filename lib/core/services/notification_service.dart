import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
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
  final Map<int, Timer> _backupTimers = {}; // Track backup timers for scheduled notifications

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

    final initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    final bool? initialized = await _plugin.initialize(initSettings);
    debugPrint('🔔 Notification plugin initialized: $initialized');

    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        // Request notification permission explicitly (Android 13+)
        final bool? granted = await androidPlugin.requestNotificationsPermission();
        debugPrint('🔔 Android notification permission: $granted');
        
        // Request exact alarm permission if needed
        final bool? exactAlarmGranted = await androidPlugin.requestExactAlarmsPermission();
        debugPrint('🔔 Android exact alarm permission: $exactAlarmGranted');
        
        // Create notification channel with proper settings
        const AndroidNotificationChannel ch = AndroidNotificationChannel(
          'reminders_channel',
          'Reminders',
          description: 'DiaFootCare reminders',
          importance: Importance.max,
          showBadge: true,
          playSound: true,
          enableVibration: true,
        );
        
        await androidPlugin.createNotificationChannel(ch);
        debugPrint('✅ Notification channel created');
      }
    }

    _ready = true;
    debugPrint('✅ NotificationService ready');
  }

  /// Map your string id to a stable int for the system.
  int notifIdFromKey(String key) => key.hashCode & 0x7fffffff;

  Future<void> cancel(int id) async {
    if (!_ready) return;
    // Cancel backup timer if exists
    _backupTimers[id]?.cancel();
    _backupTimers.remove(id);
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    // Cancel all backup timers
    for (var timer in _backupTimers.values) {
      timer.cancel();
    }
    _backupTimers.clear();
    await _plugin.cancelAll();
  }

  /// Schedule a one-off notification at a specific local DateTime.
  Future<void> scheduleOneOff({
    required int id,
    required String title,
    required String body,
    required DateTime whenLocal,
  }) async {
    if (!_ready) {
      debugPrint('❌ NotificationService not ready!');
      return;
    }
    
    debugPrint('📅 scheduleOneOff: id=$id, title=$title, when=$whenLocal');
    
    // Create TZDateTime directly from local DateTime components
    // This ensures we're using the correct local timezone without conversion issues
    final zdt = tz.TZDateTime(
      tz.local,
      whenLocal.year,
      whenLocal.month,
      whenLocal.day,
      whenLocal.hour,
      whenLocal.minute,
      whenLocal.second,
    );
    final now = tz.TZDateTime.now(tz.local);
    
    debugPrint('📅 Created TZDateTime: $zdt (now: $now)');
    
    if (zdt.isBefore(now)) {
      debugPrint('⚠️ Cannot schedule notification in the past: $zdt (current: $now)');
      return; // don't schedule past
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'reminders_channel',
        'Reminders',
        channelDescription: 'DiaFootCare reminders',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      // Calculate time until notification
      final secondsUntil = zdt.difference(now).inSeconds;
      
      // For notifications less than 5 minutes away, ALWAYS use a backup timer
      // Android scheduled notifications can be unreliable, especially on emulators
      if (secondsUntil <= 300 && secondsUntil > 0) {
        debugPrint('⚠️ Notification is scheduled for ${secondsUntil}s from now');
        debugPrint('   Setting up backup timer to ensure notification shows...');
        
        // Cancel any existing backup timer for this ID
        _backupTimers[id]?.cancel();
        
        // Backup: Use a timer to ensure notification shows (with 1 second buffer)
        _backupTimers[id] = Timer(Duration(seconds: secondsUntil + 1), () async {
          debugPrint('🔔 Backup timer fired for notification ID: $id');
          debugPrint('   Showing notification now as backup...');
          try {
            await _plugin.show(
              id,
              title,
              body,
              details,
            );
            debugPrint('✅ Backup notification shown successfully');
            _backupTimers.remove(id);
          } catch (e) {
            debugPrint('❌ Backup notification failed: $e');
          }
        });
      }
      
      // Schedule the notification
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
      
      debugPrint('✅ One-off notification scheduled successfully for: $zdt');
      debugPrint('⏰ Notification will fire in: ${zdt.difference(now).inMinutes} minutes');
      
      if (secondsUntil <= 300 && secondsUntil > 0) {
        debugPrint('🔄 Backup timer active - notification will show via timer if scheduled one fails');
      }
      
      // Verify notification is pending (Android only)
      if (!kIsWeb && Platform.isAndroid) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          try {
            final activeNotifications = await androidPlugin.getActiveNotifications();
            debugPrint('📋 Active notifications count: ${activeNotifications.length}');
          } catch (e) {
            debugPrint('⚠️ Could not check active notifications: $e');
          }
        }
      }
      
      return;
    } catch (e, stackTrace) {
      debugPrint('❌ Error scheduling one-off notification: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Schedule a **daily** notification at [hour:minute] local.
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    if (!_ready) {
      debugPrint('❌ NotificationService not ready!');
      return;
    }
    
    debugPrint('📅 scheduleDaily: id=$id, title=$title, time=$hour:$minute');
    
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'reminders_channel',
        'Reminders',
        channelDescription: 'DiaFootCare reminders',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (next.isBefore(now)) {
      debugPrint('⏰ Scheduled time is in the past, scheduling for tomorrow');
      next = next.add(const Duration(days: 1));
    }
    
    debugPrint('⏰ Next notification will fire at: ${next.toString()}');

    try {
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
      debugPrint('✅ Daily notification scheduled successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error in zonedSchedule: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
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
        android: AndroidNotificationDetails(
          'reminders_channel',
          'Reminders',
          channelDescription: 'DiaFootCare reminders',
          importance: Importance.max,
          priority: Priority.max,
          showWhen: true,
          enableVibration: true,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
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

  /// Test notification - shows immediately for debugging
  Future<void> testNotification() async {
    if (!_ready) {
      debugPrint('❌ NotificationService not ready!');
      return;
    }
    
    debugPrint('🧪 Testing immediate notification...');
    
    // Check permissions first
    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final bool? granted = await androidPlugin.requestNotificationsPermission();
        debugPrint('🧪 Test notification permission: $granted');
        if (granted != true) {
          debugPrint('❌ Notification permission not granted!');
          return;
        }
      }
    }
    
    final android = AndroidNotificationDetails(
      'reminders_channel',
      'Reminders',
      channelDescription: 'DiaFootCare reminders',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );
    const iOS = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    try {
      await _plugin.show(
        999,
        '🧪 Test Reminder',
        'This is a test notification. If you see this, notifications are working!',
        NotificationDetails(android: android, iOS: iOS),
      );
      debugPrint('✅ Test notification shown successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error showing test notification: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }
  
  /// Schedule a test notification for 5 seconds from now
  Future<void> scheduleTestNotificationIn5Seconds() async {
    if (!_ready) {
      debugPrint('❌ NotificationService not ready!');
      return;
    }
    
    final now = tz.TZDateTime.now(tz.local);
    final in5Seconds = now.add(const Duration(seconds: 5));
    
    debugPrint('🧪 Scheduling test notification for: $in5Seconds (5 seconds from now)');
    
    await scheduleOneOff(
      id: 999,
      title: '🧪 Test Reminder',
      body: 'This is a scheduled test notification. If you see this, scheduling works!',
      whenLocal: DateTime(
        in5Seconds.year,
        in5Seconds.month,
        in5Seconds.day,
        in5Seconds.hour,
        in5Seconds.minute,
        in5Seconds.second,
      ),
    );
  }
  
  /// Check if notification permissions are granted
  Future<bool> areNotificationsEnabled() async {
    if (!_ready) return false;
    
    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final bool? granted = await androidPlugin.areNotificationsEnabled();
        return granted ?? false;
      }
    }
    return false;
  }
  
  /// Request notification permissions (Android 13+)
  Future<bool> requestNotificationPermission() async {
    if (!_ready) return false;
    
    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final bool? granted = await androidPlugin.requestNotificationsPermission();
        return granted ?? false;
      }
    }
    return false;
  }
}



