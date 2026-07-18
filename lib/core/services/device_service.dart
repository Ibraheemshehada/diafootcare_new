import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:io' show Platform;

import '../network/api_client.dart';

/// The identity of this install.
///
/// A UUID v4 generated on first launch and kept locally. Deliberately **not** a
/// hardware identifier: MAC address is unavailable to apps on Android 6+ (they
/// receive 02:00:00:00:00:00) and Play policy forbids non-resettable hardware
/// IDs for tracking, while location is disproportionate as an identity key for
/// a health app. An app-scoped UUID is what Google recommends, and it disappears
/// on uninstall, which is what a participant would expect.
class DeviceService {
  DeviceService._();
  static final DeviceService I = DeviceService._();

  static const _key = 'device_uuid';
  String? _cached;

  Future<String> deviceUuid() async {
    if (_cached != null) return _cached!;

    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_key);

    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_key, id);
    }

    _cached = id;
    return id;
  }

  String get platform => Platform.isIOS ? 'ios' : 'android';

  /// Registers (or refreshes) this install against the API.
  ///
  /// Idempotent server-side on `device_uuid`, so calling it on every launch is
  /// safe and doubles as a "last seen" heartbeat. Never throws: a failure here
  /// must not block a patient from using an offline-capable app.
  Future<bool> register({String mode = 'offline', String? appVersion}) async {
    try {
      final res = await ApiClient.I.dio.post('/devices/register', data: {
        'device_uuid': await deviceUuid(),
        'platform': platform,
        'mode': mode,
        if (appVersion != null) 'app_version': appVersion,
      });

      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateMode({String? mode, bool? modelsDownloaded}) async {
    try {
      final res = await ApiClient.I.dio.patch(
        '/devices/${await deviceUuid()}/mode',
        data: {
          if (mode != null) 'mode': mode,
          if (modelsDownloaded != null) 'models_downloaded': modelsDownloaded,
        },
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
