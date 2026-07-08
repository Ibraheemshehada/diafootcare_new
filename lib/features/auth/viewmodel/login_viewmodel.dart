import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Firebase login method
  Future<void> loginUser(BuildContext context) async {
    if (!validateForm()) return;

    isLoading = true;
    notifyListeners();

    try {
      // Sign in with email and password
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      final user = userCredential.user;
      
      // ✅ Save user data locally if not already saved
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        final savedFirstName = prefs.getString('user_firstName');
        
        // If no local data, try to get from Firebase
        if (savedFirstName == null || savedFirstName.isEmpty) {
          final displayName = user.displayName;
          final email = user.email ?? emailController.text.trim();
          
          if (displayName != null && displayName.isNotEmpty) {
            final parts = displayName.split(' ');
            final firstName = parts.first;
            final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
            
            await prefs.setString('user_firstName', firstName);
            await prefs.setString('user_lastName', lastName);
            await prefs.setString('user_email', email);
            await prefs.setString('user_fullName', displayName);
            debugPrint('💾 User data loaded from Firebase and saved locally: $displayName ($email)');
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

    } on FirebaseAuthException catch (e) {
      // Localized, non-technical messages — never expose the Firebase code.
      String errorMessage = 'auth_error_generic'.tr();
      if (e.code == 'user-not-found') {
        errorMessage = 'auth_user_not_found'.tr();
      } else if (e.code == 'wrong-password') {
        errorMessage = 'auth_wrong_password'.tr();
      } else if (e.code == 'invalid-email') {
        errorMessage = 'auth_invalid_email'.tr();
      } else if (e.code == 'invalid-credential') {
        errorMessage = 'auth_invalid_credential'.tr();
      }
      if (context.mounted) {
        await showAppError(context, errorMessage, technicalDetail: e.code);
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

  /// Continue without a Firebase account. Persists a guest flag so the splash
  /// screen keeps letting the user in until they log out.
  Future<void> continueAsGuest(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest', true);
    await prefs.setBool('rememberMe', false);
    await prefs.setString('user_firstName', 'Guest');
    await prefs.setString('user_lastName', '');
    await prefs.remove('user_email');
    debugPrint('👤 Continuing as guest');

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
