// Stub implementation for non-web platforms
// This file provides no-op implementations when dart:html is not available

/// Stub function for requestPermission - returns 'denied' on non-web platforms
Future<String> requestNotificationPermission() async => 'denied';

/// Stub function for creating notifications - no-op on non-web platforms
void createNotification(String title, {String? body, String? icon}) {
  // No-op on non-web platforms
}
