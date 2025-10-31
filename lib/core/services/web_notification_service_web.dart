// Web implementation using dart:html
import 'dart:html' as html;

/// Web implementation: request permission from browser
Future<String> requestNotificationPermission() async {
  return await html.Notification.requestPermission();
}

/// Web implementation: create a browser notification
void createNotification(String title, {String? body, String? icon}) {
  html.Notification(
    title,
    body: body,
    icon: icon ?? '/favicon.png',
  );
}

