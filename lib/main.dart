import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:firebase_core/firebase_core.dart';
import 'core/services/notification_service.dart';
import 'core/services/web_notification_service.dart';
import 'features/wound/analysis/services/ai_service.dart';  // ✅ Import AI service
import 'firebase_options.dart';

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
        debugPrint("⚠️ Exact alarm permission denied - reminders may be delayed");
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

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            details.exceptionAsString(),
            style: TextStyle(color: Colors.red, fontSize: 16),
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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await EasyLocalization.ensureInitialized();

  // ✅ Initialize AI Service for wound analysis
  try {
    await AiService.instance.init();
    debugPrint('✅ AI Service initialized successfully');
  } catch (e) {
    debugPrint('⚠️ AI Service initialization failed: $e');
    debugPrint('   App will use fallback data if model is unavailable');
  }

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
    await requestExactAlarmPermission();  // For Android 12+ exact alarm scheduling
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

