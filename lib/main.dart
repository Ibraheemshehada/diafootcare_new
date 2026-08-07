import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show SystemChrome, DeviceOrientation;

import 'core/services/notification_service.dart';
import 'core/services/analytics_service.dart';
import 'core/services/background_sync.dart';
import 'core/services/sync_service.dart';
import 'core/services/web_notification_service.dart';

import 'package:easy_localization/easy_localization.dart';
import 'features/glucose/glucose_unit.dart';

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'app.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait-only. Every screen (Home hero, 2-column services grid, charts,
  // surveys, wound-capture camera) is designed for a tall viewport; landscape
  // left the services grid unreachable behind an oversized hero card. This is
  // a focused health app for elderly users, so we lock orientation rather than
  // maintain a second landscape layout. The Android manifest also pins
  // `screenOrientation="portrait"` to avoid the activity being recreated on
  // rotation before Flutter even starts.
  await SystemChrome.setPreferredOrientations(
    const [DeviceOrientation.portraitUp],
  );

  // Record every framework error locally (study "error logs") and show the
  // user a calm, readable message instead of a raw exception string.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AnalyticsService.I.logError(details.exceptionAsString());
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    AnalyticsService.I.logError(details.exceptionAsString());
    // Never surface a raw exception/stack trace to the patient. Guard the
    // lookup: this can run before localization is ready, or above MaterialApp.
    String message;
    try {
      message = 'dialog_error_generic'.tr();
    } catch (_) {
      message = 'Something went wrong. Please try again.';
    }
    // MaterialApp supplies Directionality/Theme/MediaQuery, which the error
    // widget may otherwise lack when the failure is near the tree root.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 44, color: Colors.red),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
    debugPrint('✅ sqflite web factory initialized');
  }

  // Initialize Android Alarm Manager only on Android platform
  if (!kIsWeb && Platform.isAndroid) {
    await AndroidAlarmManager.initialize();
    debugPrint('✅ Android Alarm Manager initialized');
  }

  // Notification setup and localization are independent, so run them together
  // instead of one after the other. Neither prompts the user any more (see
  // NotificationService.init), so the first frame is not blocked behind a
  // permission dialog.
  await Future.wait([
    NotificationService.I.init(),
    EasyLocalization.ensureInitialized(),
    // Read before the first frame: a reading rendered in mg/dL and then
    // relabelled mmol/L a moment later is a misread waiting to happen.
    GlucoseUnitPref.load(),
  ]);

  // Log this launch for the study's engagement metrics (local-only, non-blocking).
  AnalyticsService.I.logAppOpen();

  // Start draining the upload queue. Deliberately not awaited: sync must never
  // be on the path of the app becoming usable, and it no-ops when the device is
  // offline or nobody is signed in.
  unawaited(SyncService.I.start());

  // Drain the queue when the app goes to the background: that is when a
  // session's records are complete and the user is least likely to notice.
  // AppLifecycleListener is used rather than making the root widget stateful
  // purely to observe lifecycle.
  AppLifecycleListener(
    onPause: () => unawaited(SyncService.I.onAppPaused()),
  );

  // Keeps uploading while the app is closed. Android only; see BackgroundSync.
  unawaited(BackgroundSync.register());

  // ℹ️ AI models are NOT loaded here. Interpreter.fromAsset does a synchronous
  // native load of ~220MB of TFLite models on the UI isolate, which freezes the
  // first frame and triggers an ANR. Nothing on Home/Capture needs the models —
  // they are loaded lazily on the first analysis (AiService.analyzeWound() calls
  // init() itself), while the analysis loading screen is already showing a spinner.

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      saveLocale: true,
      useOnlyLangCode: true,
      child: const DiaFootApp(),
    ),
  );

  // Permissions are requested AFTER the first frame, not before it, so the
  // splash appears instantly instead of behind a stack of system dialogs.
  // Fire-and-forget: nothing on the first screen depends on the outcome.
  //   - Notifications / exact alarms: NotificationService.requestPermissions().
  //   - Camera: intentionally NOT requested here. The camera plugin prompts
  //     contextually the first time the Capture screen opens the camera, which
  //     is the moment the request actually makes sense.
  if (kIsWeb) {
    unawaited(WebNotificationService.instance.requestPermission());
  } else {
    unawaited(NotificationService.I.requestPermissions());
  }
}
