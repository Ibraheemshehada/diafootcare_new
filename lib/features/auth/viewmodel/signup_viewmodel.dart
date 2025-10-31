import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/auth_services.dart';
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

  // Sign up using Firebase AuthService
  Future<void> signUp(BuildContext context) async {
    if (!validate()) return;

    isLoading = true;
    notifyListeners();

    try {
      final email = emailController.text.trim();
      final firstName = firstNameController.text.trim();
      final lastName = lastNameController.text.trim();
      final password = passwordController.text;

      // Create user account
      final result = await _authService.signUp(email, password);

      if (result != null) {
        // Update Firebase user display name
        await result.updateDisplayName('$firstName $lastName');
        await result.reload();

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
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Signed up successfully'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          
          // Navigate to main shell (home screen) - this will create fresh ViewModels that load the saved data
          Navigator.pushReplacementNamed(context, AppRoutes.mainShell);
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sign-up failed. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Sign-up failed. Please try again.';
      if (e.code == 'email-already-in-use') {
        errorMessage = 'This email is already registered.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email format.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Password is too weak.';
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint('Sign-up error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unexpected error: $e'), backgroundColor: Colors.red),
        );
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
