import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;

// Conditional imports: use web implementation on web, stub on other platforms
import 'web_notification_service_stub.dart'
    if (dart.library.html) 'web_notification_service_web.dart';

/// Web-specific notification service using JavaScript timers
class WebNotificationService {
  static final WebNotificationService instance = WebNotificationService._();
  WebNotificationService._();

  final Map<int, Timer> _scheduledTimers = {};

  /// Initialize and request permission
  Future<bool> requestPermission() async {
    if (!kIsWeb) return false;

    try {
      final permission = await requestNotificationPermission();
      return permission == 'granted';
    } catch (e) {
      print('❌ Web notification permission error: $e');
      return false;
    }
  }

  /// Show an immediate notification
  void showNow({required String title, required String body, String? icon}) {
    if (!kIsWeb) return;

    try {
      createNotification(title, body: body, icon: icon);
      print('✅ Web notification shown: $title');
    } catch (e) {
      print('❌ Error showing web notification: $e');
    }
  }

  /// Schedule a notification at a specific time
  void scheduleAt({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String? icon,
  }) {
    if (!kIsWeb) return;

    // Cancel existing timer with same ID
    cancel(id);

    final now = DateTime.now();
    final delay = when.difference(now);

    if (delay.isNegative) {
      print('⚠️ Cannot schedule notification in the past: $when');
      return;
    }

    print('🔔 Scheduling web notification "$title" for ${when.toString()}');
    print(
      '⏰ Notification will trigger in ${delay.inMinutes} minutes and ${delay.inSeconds % 60} seconds',
    );

    final timer = Timer(delay, () {
      showNow(title: title, body: body, icon: icon);
      _scheduledTimers.remove(id);
    });

    _scheduledTimers[id] = timer;
  }

  /// Cancel a scheduled notification
  void cancel(int id) {
    final timer = _scheduledTimers.remove(id);
    if (timer != null) {
      timer.cancel();
      print('🚫 Cancelled web notification #$id');
    }
  }

  /// Cancel all scheduled notifications
  void cancelAll() {
    for (final timer in _scheduledTimers.values) {
      timer.cancel();
    }
    _scheduledTimers.clear();
    print('🚫 Cancelled all web notifications');
  }

  /// Get count of scheduled notifications
  int get scheduledCount => _scheduledTimers.length;
}
