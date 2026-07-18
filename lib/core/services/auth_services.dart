// lib/core/services/auth_services.dart
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import 'device_service.dart';
import 'sync_service.dart';

/// The signed-in participant, as the API describes them.
class AppUser {
  final int id;
  final String name;
  final String? email;
  final String role;
  final String locale;
  final int? patientId;
  final bool isGuest;

  const AppUser({
    required this.id,
    required this.name,
    this.email,
    required this.role,
    required this.locale,
    this.patientId,
    this.isGuest = false,
  });

  factory AppUser.fromMap(Map<String, dynamic> m, {bool guest = false}) => AppUser(
        id: (m['id'] as num).toInt(),
        name: (m['name'] ?? '') as String,
        email: m['email'] as String?,
        role: (m['role'] ?? 'patient') as String,
        locale: (m['locale'] ?? 'en') as String,
        patientId: (m['patient_id'] as num?)?.toInt(),
        isGuest: guest,
      );

  String get displayName => name.trim().isEmpty ? (email ?? 'Participant') : name;
}

/// Authentication against the DiaFootCare Laravel API.
///
/// Replaces the previous Firebase implementation. Identity now comes from the
/// same server that stores the clinical records, so a patient's login and their
/// data cannot disagree about who they are — with two identity systems, records
/// eventually attach to the wrong person, which in a clinical app is a safety
/// problem rather than an inconvenience.
class AuthService {
  static const _guestFlagKey = 'is_guest';

  AppUser? _current;
  AppUser? get currentUser => _current;

  Future<bool> get isSignedIn async => ApiClient.I.hasToken;

  // ---------- Sign in / up / out ----------

  Future<AppUser> signIn(String email, String password) async {
    final res = await ApiClient.I.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
      'device_name': DeviceService.I.platform,
    });

    if (res.statusCode != 200) throw ApiException.fromResponse(res);

    return _persist(res.data, guest: false);
  }

  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
    String? locale,
  }) async {
    final res = await ApiClient.I.dio.post('/auth/register', data: {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': password,
      if (locale != null) 'locale': locale,
    });

    if (res.statusCode != 201 && res.statusCode != 200) {
      throw ApiException.fromResponse(res);
    }

    return _persist(res.data, guest: false);
  }

  /// Anonymous participation, keyed to this install's device UUID.
  ///
  /// Idempotent server-side, so reopening the app resumes the same participant
  /// rather than creating a second anonymous record for one person.
  Future<AppUser> continueAsGuest({String mode = 'offline', String? locale}) async {
    final res = await ApiClient.I.dio.post('/auth/guest', data: {
      'device_uuid': await DeviceService.I.deviceUuid(),
      'platform': DeviceService.I.platform,
      'mode': mode,
      if (locale != null) 'locale': locale,
    });

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ApiException.fromResponse(res);
    }

    return _persist(res.data, guest: true);
  }

  /// Turns the current anonymous session into a real account, keeping the
  /// history already recorded against it.
  Future<AppUser> claimGuestAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await ApiClient.I.dio.post('/auth/claim', data: {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': password,
    });

    if (res.statusCode != 200) throw ApiException.fromResponse(res);

    return _persist(res.data, guest: false);
  }

  Future<void> signOut() async {
    // Revoke server-side first, but never let a network failure trap someone in
    // a session they asked to leave.
    try {
      await ApiClient.I.dio.post('/auth/logout');
    } catch (_) {}

    await ApiClient.I.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestFlagKey);
    _current = null;
  }

  /// Resolves the stored token to a user. Returns null if there is no valid
  /// session, which is the signal to show the login screen.
  Future<AppUser?> restoreSession() async {
    if (!await ApiClient.I.hasToken) return null;

    try {
      final res = await ApiClient.I.dio.get('/auth/me');
      if (res.statusCode != 200) return null;

      final prefs = await SharedPreferences.getInstance();
      _current = AppUser.fromMap(
        Map<String, dynamic>.from(res.data['user'] as Map),
        guest: prefs.getBool(_guestFlagKey) ?? false,
      );
      return _current;
    } catch (_) {
      // Offline with a token we cannot verify. The app is offline-first, so the
      // caller decides whether to proceed; we simply cannot confirm identity.
      return null;
    }
  }

  // ---------- Password ----------

  Future<void> updatePasswordWhileLoggedIn(String newPassword) async {
    final res = await ApiClient.I.dio.post('/auth/password', data: {
      'password': newPassword,
      'password_confirmation': newPassword,
    });

    if (res.statusCode != 200) throw ApiException.fromResponse(res);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final res = await ApiClient.I.dio.post('/auth/forgot-password', data: {'email': email});
    if (res.statusCode != 200) throw ApiException.fromResponse(res);
  }

  Future<void> updateDisplayName(String displayName) async {
    final res = await ApiClient.I.dio.post('/auth/profile', data: {'name': displayName});
    if (res.statusCode != 200) throw ApiException.fromResponse(res);

    if (_current != null) {
      _current = AppUser(
        id: _current!.id,
        name: displayName,
        email: _current!.email,
        role: _current!.role,
        locale: _current!.locale,
        patientId: _current!.patientId,
        isGuest: _current!.isGuest,
      );
    }
  }

  // ---------- internal ----------

  Future<AppUser> _persist(dynamic body, {required bool guest}) async {
    final map = Map<String, dynamic>.from(body as Map);
    await ApiClient.I.saveToken(map['token'] as String);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestFlagKey, guest);

    _current = AppUser.fromMap(
      Map<String, dynamic>.from(map['user'] as Map),
      guest: guest,
    );

    // Registering here means a device row exists before any sync is attempted.
    // Fire-and-forget: a registration failure must not block sign-in.
    unawaited(DeviceService.I.register().then((_) {
      // Drain whatever accumulated while signed out, rather than waiting for the
      // next connectivity change to notice it.
      SyncService.I.syncNow();
    }));

    return _current!;
  }
}
