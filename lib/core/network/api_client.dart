import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// HTTP client for the DiaFootCare Laravel API.
///
/// Single entry point for every network call, so the token, timeouts and retry
/// policy are defined once rather than per screen.
class ApiClient {
  ApiClient._();
  static final ApiClient I = ApiClient._();

  /// Override at build time:
  ///   flutter run --dart-define=API_BASE_URL=https://api.example.com/api/v1
  ///
  /// The default is the LIVE production server, on purpose. It used to be the
  /// Android-emulator loopback (`http://10.0.2.2:8123`), which built silently
  /// into release APKs and shipped an app that only worked against a dev host —
  /// a bug that looked fine until it was on a real device. A default that fails
  /// safe everywhere is worth more than one that only works when someone
  /// remembers the flag. `--dart-define=API_BASE_URL=...` still overrides this
  /// for local development. HTTPS with a publicly-trusted chain, so no iOS ATS
  /// exception is needed — if one ever seems necessary, something else is wrong.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://diafootcare.tech/api/v1',
  );

  /// The Sanctum token lives in the platform keystore, not SharedPreferences.
  /// It grants access to a patient's clinical record, so it is treated as a
  /// credential rather than a preference.
  static const _tokenKey = 'dfc_api_token';
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _cachedToken;

  late final Dio dio = _build();

  Dio _build() {
    final d = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
      // Let non-2xx through to the interceptor so error bodies stay readable
      // instead of being swallowed into a generic DioException.
      validateStatus: (s) => s != null && s < 500,
    ));

    d.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await readToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        // A 401 means the token was revoked or expired server-side. Drop it so
        // the app stops sending a credential that no longer works.
        if (response.statusCode == 401) {
          clearToken();
        }
        handler.next(response);
      },
      onError: (e, handler) {
        if (kDebugMode) {
          debugPrint('API error ${e.requestOptions.path}: ${e.message}');
        }
        handler.next(e);
      },
    ));

    return d;
  }

  Future<String?> readToken() async {
    _cachedToken ??= await _storage.read(key: _tokenKey);
    return _cachedToken;
  }

  Future<void> saveToken(String token) async {
    _cachedToken = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> clearToken() async {
    _cachedToken = null;
    await _storage.delete(key: _tokenKey);
  }

  Future<bool> get hasToken async => (await readToken()) != null;
}

/// A failed API call, carrying a message already fit to show a user.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  /// Field-level validation errors from Laravel (422), if any.
  final Map<String, List<String>> errors;

  ApiException(this.message, {this.statusCode, this.errors = const {}});

  /// Builds an exception from a Laravel error response.
  ///
  /// Prefers the first field error over the generic "The given data was
  /// invalid." envelope, because the field message is the one that tells the
  /// user what to actually fix.
  factory ApiException.fromResponse(Response? res) {
    final data = res?.data;

    if (data is Map) {
      final rawErrors = data['errors'];
      final parsed = <String, List<String>>{};

      if (rawErrors is Map) {
        rawErrors.forEach((k, v) {
          parsed['$k'] = (v is List) ? v.map((e) => '$e').toList() : ['$v'];
        });
      }

      final first = parsed.values.isNotEmpty && parsed.values.first.isNotEmpty
          ? parsed.values.first.first
          : null;

      return ApiException(
        first ?? (data['message']?.toString() ?? 'Request failed.'),
        statusCode: res?.statusCode,
        errors: parsed,
      );
    }

    return ApiException('Request failed.', statusCode: res?.statusCode);
  }

  bool get isUnauthorized => statusCode == 401;
  bool get isConflict => statusCode == 409;

  @override
  String toString() => message;
}
