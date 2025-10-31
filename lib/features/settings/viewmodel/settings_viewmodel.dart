import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsViewModel extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _notificationsEnabled = false;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkPreferred => _themeMode == ThemeMode.dark;
  bool get notificationsEnabled => _notificationsEnabled;

  void setDarkMode(bool v) {
    _themeMode = v ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setNotifications(bool v) {
    _notificationsEnabled = v;
    notifyListeners();
  }

  bool _acceptedTerms = false;
  bool get acceptedTerms => _acceptedTerms;

  Future<void> loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    _acceptedTerms = p.getBool('accepted_terms') ?? false;
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
