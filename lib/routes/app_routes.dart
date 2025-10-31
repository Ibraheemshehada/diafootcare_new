import 'package:camera/camera.dart';
import 'package:flutter/material.dart';


import '../features/auth/screens/forget_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/history/screens/wound_history_screen.dart';
import '../features/notes/screens/notes_all_screen.dart';
import '../features/notes/screens/notes_screen.dart';
import '../features/profile/screens/change_password_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/reminders/screens/reminders_screen.dart';
import '../features/settings/screens/export_data_screen.dart';
import '../features/settings/screens/senior_tips_screen.dart';

import '../features/shell/screens/main_shell.dart';
import '../features/wound/capture/screens/capture_screen.dart';
import '../features/wound/capture/screens/preview_screen.dart';

class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String forgetPassword = '/forgetPassword';
  static const confirm = '/confirm';
  static const String otp = '/otp-verify';
  static const String resetSuccess = '/reset-success';
  static const String setPassword = '/set-password';
  static const String signup = '/signup';

  // Shell route
  static const String mainShell = '/'; // Default home route → shell

  // You can still keep named routes for subpages if needed
  static const String capture = '/capture';
  static const String measure = '/WoundHistoryScreen';
  static const String reminders = '/reminders';
  static const String notes = '/notes';
  static const String preview = '/preview';
  static const String notesAll = '/notes/all';
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String changePassword = '/profile/change_password';
  static const String seniorTips = '/seniorTips';
  static const exportData = '/exportData';



  static final Map<String, WidgetBuilder> routes = {
    splash: (_) => const SplashScreen(),
    login: (_) => const LoginScreen(),
    signup: (_) => const SignUpScreen(),
    forgetPassword: (_) => const ForgetPasswordScreen(),

    seniorTips: (_) => const SeniorTipsScreen(),
    // The shell replaces direct HomeScreen usage
    mainShell: (_) => const MainShell(),
    reminders: (_) => const RemindersScreen(),

    // Capture flow
    capture: (_) => const CaptureScreen(),
    notes: (_) => const NotesScreen(),
    notesAll: (_) => const NotesAllScreen(),
    measure: (_) => const WoundHistoryScreen(),
    exportData: (_) => const ExportDataScreen(),
    profile: (_) => const ProfileScreen(),
    editProfile: (_) => const EditProfileScreen(),
    changePassword: (_) => const ChangePasswordScreen(),

    preview: (context) {
      // For preview, pass XFile via arguments
      final args = ModalRoute.of(context)!.settings.arguments;
      return PreviewScreen(file: args as XFile);
    },
  };
}
