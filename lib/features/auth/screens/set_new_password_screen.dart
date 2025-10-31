
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

import '../viewmodel/set_password_viewmodel.dart';
import '../widgets/set_password_form.dart';

class SetNewPasswordScreen extends StatelessWidget {
  const SetNewPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 👇 read args passed from ResetSuccess / OTP
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final email = args['email'] as String;
    final code  = args['code']  as String;

    return ChangeNotifierProvider(
      // 👇 provide the VM with email + code
      create: (_) => SetPasswordViewModel(email: email, code: code),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              children: [
                SizedBox(height: 40.h),
                SvgPicture.asset(
                  "assets/svg/password_reset.svg",
                  height: 220.h,
                ),
                SizedBox(height: 24.h),
                Text(
                  tr('set_password_title'),
                  style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8.h),
                Text(
                  tr('set_password_subtitle'),
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),
                const SetPasswordForm(), // uses the provided VM
              ],
            ),
          ),
        ),
      ),
    );
  }
}
