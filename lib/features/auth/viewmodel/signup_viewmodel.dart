import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/auth_services.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../routes/app_routes.dart';

class SignUpViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();

  // Controllers for user input
  final emailController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // Error messages
  String? emailError;
  String? firstNameError;
  String? lastNameError;
  String? passwordError;
  String? confirmPasswordError;

  bool isLoading = false;
  bool isPasswordVisible = false;

  // Toggle password visibility
  void togglePasswordVisibility() {
    isPasswordVisible = !isPasswordVisible;
    notifyListeners();
  }

  // Form validation
  bool validate() {
    emailError = null;
    firstNameError = null;
    lastNameError = null;
    passwordError = null;
    confirmPasswordError = null;

    if (emailController.text.isEmpty) emailError = 'email_required';
    if (firstNameController.text.isEmpty) firstNameError = 'first_name_required';
    if (lastNameController.text.isEmpty) lastNameError = 'last_name_required';
    if (passwordController.text.length < 6) passwordError = 'password_short';
    if (passwordController.text != confirmPasswordController.text) {
      confirmPasswordError = 'password_mismatch';
    }

    notifyListeners();
    return emailError == null &&
        firstNameError == null &&
        lastNameError == null &&
        passwordError == null &&
        confirmPasswordError == null;
  }

  // Save user data locally
  Future<void> _saveUserDataLocally({
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_firstName', firstName);
    await prefs.setString('user_lastName', lastName);
    await prefs.setString('user_email', email);
    await prefs.setString('user_fullName', '$firstName $lastName');
    debugPrint('💾 User data saved locally: $firstName $lastName ($email)');
  }

  // Sign up against the DiaFootCare API.
  Future<void> signUp(BuildContext context) async {
    if (!validate()) return;

    isLoading = true;
    notifyListeners();

    try {
      final email = emailController.text.trim();
      final firstName = firstNameController.text.trim();
      final lastName = lastNameController.text.trim();
      final password = passwordController.text;

      // Create the account on the API. The name is supplied up front, so there
      // is no second call to set a display name afterwards.
      await _authService.signUp(
        name: '$firstName $lastName'.trim(),
        email: email,
        password: password,
      );

      {
        // Save user data locally
        await _saveUserDataLocally(
          firstName: firstName,
          lastName: lastName,
          email: email,
        );

        // Save "Remember Me" preference
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('rememberMe', true);

        if (context.mounted) {
          // Give a small delay to ensure data is saved before navigating
          await Future.delayed(const Duration(milliseconds: 100));

          await showAppSuccess(context, 'auth_signup_success'.tr());

          // Navigate to main shell (home screen) - this will create fresh ViewModels that load the saved data
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, AppRoutes.mainShell);
          }
        }
      }
    } on ApiException catch (e) {
      // Laravel validation already says which field failed and why (duplicate
      // email, weak password); repeating that mapping here would only let the
      // two drift apart.
      if (context.mounted) {
        await showAppError(context, e.message, technicalDetail: e.statusCode);
      }
    } catch (e) {
      debugPrint('Sign-up error: $e');
      if (context.mounted) {
        await showAppError(context, 'auth_error_generic'.tr(),
            technicalDetail: e);
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}
