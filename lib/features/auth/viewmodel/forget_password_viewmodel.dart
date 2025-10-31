import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class ForgetPasswordViewModel extends ChangeNotifier {
  final emailController = TextEditingController();
  String? emailError;
  bool isLoading = false;

  // Mask for UI
  static String maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final masked = name.length <= 2
        ? '${name[0]}***'
        : '${name[0]}${'*' * (name.length - 2)}${name[name.length - 1]}';
    return '$masked@${parts[1]}';
  }

  bool _validate() {
    emailError = null;
    final email = emailController.text.trim();
    if (email.isEmpty) {
      emailError = 'email_required';     // your i18n key
    } else if (!email.contains('@')) {
      emailError = 'email_invalid';      // your i18n key
    }
    notifyListeners();
    return emailError == null;
  }

  Future<bool> sendOtp(BuildContext context) async {
    if (!_validate()) return false;

    isLoading = true;
    notifyListeners();

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('requestPasswordOtp');
      await callable.call({'email': emailController.text.trim()});
      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send OTP: $e')),
      );
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }
}
