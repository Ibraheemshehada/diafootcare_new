import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import '../../../routes/app_routes.dart';
import '../viewmodel/forget_password_viewmodel.dart';

class ForgetPasswordScreen extends StatelessWidget {
  const ForgetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ChangeNotifierProvider(
      create: (c) => ForgetPasswordViewModel(),
      child: Consumer<ForgetPasswordViewModel>(
        builder:
            (context, vm, _) => Scaffold(
              appBar: AppBar(backgroundColor: theme.scaffoldBackgroundColor,),
              body: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 80.h),
                    Center(
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/images/forget_password.png', // Use your forget image
                            height: 200.h,
                          ),
                          SizedBox(height: 24.h),
                          Text(
                            tr('forget_password_title'),
                            style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            tr('forget_password_subtitle'),
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 32.h),
                    TextFormField(
                      controller: vm.emailController,
                      decoration: InputDecoration(
                        labelText: tr('email_or_mobile'),
                        errorText:
                            vm.emailError != null ? tr(vm.emailError!) : null,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      tr('reset_warning'),
                      style: TextStyle(fontSize: 10.sp, color: Colors.grey),
                    ),
                    SizedBox(height: 40.h),
                  ],
                ),
              ),
                bottomNavigationBar: Padding(
                  padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      // onPressed: vm.isLoading ? null : () => vm.resetPassword(context),
                        onPressed: vm.isLoading ? null : () async {
                          final ok = await vm.sendOtp(context);
                          if (!ok) return;

                          final email  = vm.emailController.text.trim();
                          final masked = ForgetPasswordViewModel.maskEmail(email);

                          // go to Confirm screen with BOTH plain + masked email
                          Navigator.pushNamed(
                            context,
                            AppRoutes.confirm,
                            arguments: {'email': email, 'masked': masked},
                          );
                        },
                      child: vm.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                        tr('continue'),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                )
            ),
      ),
    );
  }
}
