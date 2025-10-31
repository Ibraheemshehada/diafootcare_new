import 'package:flutter/material.dart';
class OtpVerifyViewModel extends ChangeNotifier {
  // 6 controllers (not 5)
  final List<TextEditingController> controllers =
  List.generate(6, (_) => TextEditingController());

  bool isLoading = false;

  // handy getter
  String get code => controllers.map((c) => c.text).join();

  void onOtpChange(int index, String value, BuildContext context) {
    if (value.isNotEmpty && index < controllers.length - 1) {
      FocusScope.of(context).nextFocus();
    } else if (value.isEmpty && index > 0) {
      FocusScope.of(context).previousFocus();
    }
  }

  // resend hits your function again
  Future<void> resendEmail(BuildContext context, String email) async {
    try {
      isLoading = true; notifyListeners();
      // call your Cloud Function: requestPasswordOtp
      // (If you already wrote this elsewhere, call it from here)
      // Example:
      // await FirebaseFunctions.instance.httpsCallable('requestPasswordOtp').call({'email': email});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code was sent')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resend: $e')),
      );
    } finally {
      isLoading = false; notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final c in controllers) { c.dispose(); }
    super.dispose();
  }
}
