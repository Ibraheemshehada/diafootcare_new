import 'package:flutter/material.dart';

import '../../../core/services/auth_services.dart';

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

  // Sign up using Firebase AuthService
  Future<void> signUp(BuildContext context) async {
    if (!validate()) return;

    isLoading = true;
    notifyListeners();

    final result = await _authService.signUp(
      emailController.text,
      passwordController.text,
    );

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signed up successfully')),
      );
      Navigator.pushReplacementNamed(context, '/home'); // Navigate to home after sign-up
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-up failed')),
      );
    }

    isLoading = false;
    notifyListeners();
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
