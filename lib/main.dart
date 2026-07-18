import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show SystemChrome, DeviceOrientation;

import 'core/services/notification_service.dart';
import 'core/services/analytics_service.dart';
import 'core/services/web_notification_service.dart';

import 'package:easy_localization/easy_localization.dart';

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'app.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

Future<void> requestNotificationPermission() async {
  final status = await Permission.notification.request();
  if (status.isGranted) {
    debugPrint("✅ Notifications permission granted");
  } else {
    debugPrint("❌ Notifications permission denied");
  }
}

Future<void> requestExactAlarmPermission() async {
  if (!kIsWeb && Platform.isAndroid) {
    // Android 12+ requires this permission for exact alarms
    final status = await Permission.scheduleExactAlarm.status;
    if (!status.isGranted) {
      final result = await Permission.scheduleExactAlarm.request();
      if (result.isGranted) {
        debugPrint("✅ Exact alarm permission granted");
      } else {
        debugPrint(
          "⚠️ Exact alarm permission denied - reminders may be delayed",
        );
      }
    } else {
      debugPrint("✅ Exact alarm permission already granted");
    }
  }
}

Future<void> requestCameraPermission() async {
  final status = await Permission.camera.request();
  if (status.isGranted) {
    debugPrint("✅ Camera permission granted");
  } else {
    debugPrint("❌ Camera permission denied");
  }
}

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

  await NotificationService.I.init();
  await EasyLocalization.ensureInitialized();

  // Log this launch for the study's engagement metrics (local-only, non-blocking).
  AnalyticsService.I.logAppOpen();

  // ℹ️ AI models are NOT loaded here. Interpreter.fromAsset does a synchronous
  // native load of ~220MB of TFLite models on the UI isolate, which freezes the
  // first frame and triggers an ANR. Nothing on Home/Capture needs the models —
  // they are loaded lazily on the first analysis (AiService.analyzeWound() calls
  // init() itself), while the analysis loading screen is already showing a spinner.

  // Request permissions based on platform
  if (kIsWeb) {
    // Request web notification permission
    final granted = await WebNotificationService.instance.requestPermission();
    if (granted) {
      debugPrint("✅ Web notifications permission granted");
    } else {
      debugPrint("⚠️ Web notifications permission denied");
    }
  } else {
    // Request mobile permissions
    await requestNotificationPermission();
    await requestExactAlarmPermission(); // For Android 12+ exact alarm scheduling
    await requestCameraPermission();
  }
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
}
