import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_dialogs.dart';
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
      final res = await ApiClient.I.dio.post('/auth/reset-password', data: {
        'email': email,
        'code': code,
        'password': newPasswordController.text.trim(),
        'password_confirmation': newPasswordController.text.trim(),
      });
      if (res.statusCode != 200) throw ApiException.fromResponse(res);

      // success — was previously showing the raw key 'password_updated_success'
      if (context.mounted) {
        await showAppSuccess(context, 'password_updated_successfully'.tr());
      }

      // back to login
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.login, (_) => false);
      }
    } catch (e) {
      if (context.mounted) {
        await showAppError(context, 'password_update_failed'.tr(),
            technicalDetail: e);
      }
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
