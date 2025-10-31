import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../../../routes/app_routes.dart';

class SetPasswordViewModel extends ChangeNotifier {
  SetPasswordViewModel({required this.email, required this.code});

  final String email;  // from OTP step
  final String code;   // 6-digit OTP

  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  String? newPasswordError;
  String? confirmPasswordError;

  bool isLoading = false;
  bool isPasswordVisible = false;

  void togglePasswordVisibility() {
    isPasswordVisible = !isPasswordVisible;
    notifyListeners();
  }

  bool validateForm() {
    newPasswordError = null;
    confirmPasswordError = null;

    final p1 = newPasswordController.text.trim();
    final p2 = confirmPasswordController.text.trim();

    if (p1.length < 6) newPasswordError = 'password_short';
    if (p1 != p2) confirmPasswordError = 'password_mismatch';

    notifyListeners();
    return newPasswordError == null && confirmPasswordError == null;
  }

  Future<void> updatePassword(BuildContext context) async {
    if (!validateForm()) return;

    isLoading = true; notifyListeners();
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('verifyPasswordOtp');
      await callable.call({
        'email': email,
        'code': code,
        'newPassword': newPasswordController.text.trim(),
      });

      // success
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('password_updated_success')),
      );

      // back to login
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('update_failed')),
      );
    } finally {
      isLoading = false; notifyListeners();
    }
  }

  @override
  void dispose() {
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}
