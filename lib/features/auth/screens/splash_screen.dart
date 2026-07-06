import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../routes/app_routes.dart';
import '../../settings/screens/terms_screen.dart';
import '../../settings/viewmodel/settings_viewmodel.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final settings = context.read<SettingsViewModel>();

    // Load preferences and wait for splash screen display (~2 seconds)
    await Future.wait([
      Future.delayed(const Duration(seconds: 2)),
      settings.loadPrefs(),
    ]);

    if (!mounted) return;

    // Gate on terms acceptance
    if (!settings.acceptedTerms) {
      // Block navigation until terms are accepted
      final accepted = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const TermsScreen(blocking: true),
        ),
      );

      if (!mounted) return;

      if (accepted == true) {
        // After accepting terms, check auth state
        await _checkAuthAndNavigate();
      } else {
        // If user doesn't accept terms, decide on app behavior.
        // Here we can choose to close the app or stay on the splash screen.
        // For example, we can close the app if terms are not accepted:
        // SystemNavigator.pop();  // To exit the app (you can choose this approach)
        return; // Simply stay on splash screen if user refuses terms
      }
      return;
    }

    // If terms already accepted → Check auth state
    await _checkAuthAndNavigate();
  }

  /// Check if user is logged in and has "Remember Me" enabled
  Future<void> _checkAuthAndNavigate() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();

    // Guest session: let the user keep using the app without a Firebase
    // account until they explicitly log out (which clears this flag).
    final isGuest = prefs.getBool('is_guest') ?? false;
    if (isGuest) {
      debugPrint('👤 Guest session active → Redirecting to home');
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.mainShell);
      return;
    }

    // Check Firebase auth state
    final currentUser = FirebaseAuth.instance.currentUser;

    // Check if "Remember Me" was enabled
    final rememberMe = prefs.getBool('rememberMe') ?? false;

    if (currentUser != null && rememberMe) {
      // User is logged in and has remember me enabled → Go to home
      debugPrint('✅ User already logged in (Remember Me enabled) → Redirecting to home');
      Navigator.pushReplacementNamed(context, AppRoutes.mainShell);
    } else {
      // User not logged in or remember me disabled → Go to login
      debugPrint('ℹ️ User not logged in or Remember Me disabled → Redirecting to login');
      
      // If user exists but remember me is disabled, sign them out
      if (currentUser != null && !rememberMe) {
        await FirebaseAuth.instance.signOut();
        debugPrint('🔓 Signed out user (Remember Me was disabled)');
      }
      
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            SvgPicture.asset(
              'assets/svg/logo_light.svg',
              height: 160.h,
              width: 160.w,
              fit: BoxFit.contain,
            ),
            SizedBox(height: 24.h),

            // Localized App Name using RichText
            RichText(
              text: TextSpan(
                text: tr('app_name_light'),
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.lightBlueAccent,
                ),
                children: [
                  TextSpan(
                    text: tr('app_name_dark'),
                    style: TextStyle(color: isDark ? Colors.blue : Colors.blue),
                  ),
                ],
              ),
            ),

            const Spacer(),
            LoadingAnimationWidget.hexagonDots(
              color: const Color(0xff077FFF),
              size: 45.w,
            ),
            SizedBox(height: 36.h),
          ],
        ),
      ),
    );
  }
}
