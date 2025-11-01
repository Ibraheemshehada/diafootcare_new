import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/notification_service.dart';
import '../../../data/repositories/reminders_repo.dart';

class SettingsViewModel extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _notificationsEnabled = true; // Default to enabled

  ThemeMode get themeMode => _themeMode;
  bool get isDarkPreferred => _themeMode == ThemeMode.dark;
  bool get notificationsEnabled => _notificationsEnabled;

  void setDarkMode(bool v) {
    _themeMode = v ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> setNotifications(bool v) async {
    if (_notificationsEnabled == v) return;
    _notificationsEnabled = v;
    
    // Save to SharedPreferences
    final p = await SharedPreferences.getInstance();
    await p.setBool('notifications_enabled', v);
    
    // Actually enable/disable notifications
    final notifService = NotificationService.I;
    await notifService.init();
    
    if (!v) {
      // Disable: Cancel all scheduled notifications
      await notifService.cancelAll();
      debugPrint('🔕 All notifications cancelled (disabled by user)');
    } else {
      // Enable: Reschedule all enabled reminders
      try {
        final remindersRepo = RemindersRepo();
        final reminders = await remindersRepo.load();
        await remindersRepo.rescheduleAll(reminders);
        debugPrint('🔔 All enabled reminders rescheduled (notifications enabled)');
      } catch (e) {
        debugPrint('⚠️ Error rescheduling reminders: $e');
      }
    }
    
    notifyListeners();
  }

  bool _acceptedTerms = false;
  bool get acceptedTerms => _acceptedTerms;

  Future<void> loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    _acceptedTerms = p.getBool('accepted_terms') ?? false;
    _notificationsEnabled = p.getBool('notifications_enabled') ?? true; // Default to enabled
    notifyListeners();
  }

  Future<void> setAcceptedTerms(bool v) async {
    if (_acceptedTerms == v) return;
    _acceptedTerms = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool('accepted_terms', v);
  }
}
