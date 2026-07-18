import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/auth_services.dart';

import '../../../core/widgets/app_dialogs.dart';
import '../../../routes/app_routes.dart';

class LoginViewModel extends ChangeNotifier {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String? emailError;
  String? passwordError;

  bool isLoading = false;
  bool rememberMe = false;
  bool isPasswordVisible = false;

  // Validate form fields
  bool validateForm() {
    emailError = null;
    passwordError = null;

    if (emailController.text.isEmpty) {
      emailError = 'email_required';
    } else if (!emailController.text.contains('@')) {
      emailError = 'email_invalid';
    }

    if (passwordController.text.length < 6) {
      passwordError = 'password_short';
    }

    notifyListeners();
    return emailError == null && passwordError == null;
  }

  // Sign in against the DiaFootCare API.
  Future<void> loginUser(BuildContext context) async {
    if (!validateForm()) return;

    isLoading = true;
    notifyListeners();

    try {
      // Sign in with email and password
      final user = await AuthService().signIn(
        emailController.text.trim(),
        passwordController.text,
      );
      
      // ✅ Save user data locally if not already saved
      {
        final prefs = await SharedPreferences.getInstance();
        final savedFirstName = prefs.getString('user_firstName');
        
        // If no local data, take it from the API user.
        if (savedFirstName == null || savedFirstName.isEmpty) {
          final displayName = user.name;
          final email = user.email ?? emailController.text.trim();
          
          if (displayName.isNotEmpty) {
            final parts = displayName.split(' ');
            final firstName = parts.first;
            final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
            
            await prefs.setString('user_firstName', firstName);
            await prefs.setString('user_lastName', lastName);
            await prefs.setString('user_email', email);
            await prefs.setString('user_fullName', displayName);
            debugPrint('💾 User data loaded from API and saved locally: $displayName ($email)');
          } else {
            // If no display name, save at least email
            await prefs.setString('user_email', email);
            await prefs.setString('user_firstName', 'User');
            await prefs.setString('user_lastName', '');
            debugPrint('💾 User email saved: $email');
          }
        }
      }

      // ✅ Save "Remember Me" preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('rememberMe', rememberMe);
      debugPrint('💾 Remember Me preference saved: $rememberMe');

      // Navigate to the main screen if login is successful
      Navigator.pushReplacementNamed(context, AppRoutes.mainShell);

    } on ApiException catch (e) {
      // The API returns a message already fit to show; 401 is the credential
      // case and everything else is reported as-is rather than guessed at.
      if (context.mounted) {
        await showAppError(
          context,
          e.isUnauthorized ? 'auth_invalid_credential'.tr() : e.message,
          technicalDetail: e.statusCode,
        );
      }
    } catch (e) {
      if (context.mounted) {
        await showAppError(context, 'auth_error_generic'.tr(),
            technicalDetail: e);
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Continue without an account.
  ///
  /// Opens an anonymous session on the server keyed to this install's device
  /// UUID, so a guest's scans and usage still reach the study instead of being
  /// stranded on the phone. The server call is idempotent, so reopening the app
  /// resumes the same participant rather than creating a second one.
  ///
  /// If the server cannot be reached the user still gets in: this is an
  /// offline-first app, and refusing entry because a network call failed would
  /// break its core promise. The session is opened on a later launch instead.
  Future<void> continueAsGuest(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest', true);
    await prefs.setBool('rememberMe', false);
    await prefs.setString('user_firstName', 'Guest');
    await prefs.setString('user_lastName', '');
    await prefs.remove('user_email');

    try {
      await AuthService().continueAsGuest(
        locale: context.locale.languageCode,
      );
      debugPrint('👤 Guest session opened on the server');
    } catch (e) {
      debugPrint('👤 Continuing as guest offline (server unavailable): $e');
    }

    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.mainShell);
  }

  void toggleRememberMe(bool? value) {
    rememberMe = value ?? false;
    notifyListeners();
  }

  void togglePasswordVisibility() {
    isPasswordVisible = !isPasswordVisible;
    notifyListeners();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
