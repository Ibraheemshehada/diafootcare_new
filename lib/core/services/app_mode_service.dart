import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_service.dart';

/// How this install analyses a wound.
enum AppMode {
  /// Photos are sent to the server for analysis. Small install, needs a
  /// connection to analyse.
  online,

  /// The TFLite models are downloaded once and analysis runs on the phone.
  /// Works with no connection at all.
  offline,
}

/// The participant's choice of analysis mode.
///
/// Deliberately a first-class service rather than a preference read in place:
/// the mode decides whether the models are downloaded, which inference path
/// runs, and what a scan's `source` field says. Scattering `getBool('mode')`
/// across those three would let them disagree.
class AppModeService {
  AppModeService._();
  static final AppModeService I = AppModeService._();

  static const _key = 'app_mode';

  AppMode? _cached;

  /// Null until the participant has chosen — which is what the onboarding gate
  /// tests. "Not yet asked" is a different state from "chose online", and
  /// defaulting the unanswered case would silently make the choice for them.
  Future<AppMode?> current() async {
    if (_cached != null) return _cached;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;

    _cached = AppMode.values.asNameMap()[raw];
    return _cached;
  }

  Future<bool> hasChosen() async => (await current()) != null;

  Future<void> set(AppMode mode) async {
    _cached = mode;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);

    // Tell the server, so the dashboard's mode split reflects reality. Silent on
    // failure: the choice is already saved locally and a device with no
    // connection is exactly the one most likely to pick Offline.
    try {
      await DeviceService.I.updateMode(mode: mode.name);
    } catch (e) {
      debugPrint('ℹ️ Could not report mode to the server yet: $e');
    }
  }

  /// True when analysis should run on the phone.
  Future<bool> get isOffline async => (await current()) == AppMode.offline;
}
