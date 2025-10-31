import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../viewmodel/login_viewmodel.dart';

class LoginForm extends StatelessWidget {
  const LoginForm({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginViewModel(),
      child: Consumer<LoginViewModel>(
        builder: (context, vm, child) {
          return Form(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 40.h),

                // Email / Mobile
                Text(tr('email_or_mobile')),
                SizedBox(height: 10.h),
                TextFormField(
                  controller: vm.emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(fontSize: 16.sp),
                  decoration: InputDecoration(
                    errorText: vm.emailError != null ? tr(vm.emailError!) : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(color: Colors.blue, width: 2),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 14.h,
                    ),
                  ),
                ),

                SizedBox(height: 20.h),

                // Password
                Text(tr('password')),
                SizedBox(height: 10.h),
                TextFormField(
                  controller: vm.passwordController,
                  obscureText: !vm.isPasswordVisible,
                  style: TextStyle(fontSize: 16.sp),
                  decoration: InputDecoration(
                    errorText: vm.passwordError != null ? tr(vm.passwordError!) : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(color: Colors.blue, width: 2),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        vm.isPasswordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () => vm.togglePasswordVisibility(),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 14.h,
                    ),
                  ),
                ),

                SizedBox(height: 10.h),

                // Remember Me
                Row(
                  children: [
                    Checkbox(
                      value: vm.rememberMe,
                      onChanged: vm.toggleRememberMe,
                    ),
                    Text(
                      tr('remember_me'),
                      style: TextStyle(fontSize: 14.sp),
                    ),
                  ],
                ),

                SizedBox(height: 24.h),

                // Login button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: vm.isLoading ? null : () => vm.loginUser(context),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                    ),
                    child: vm.isLoading
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : Text(
                      tr('login'),
                      style: TextStyle(fontSize: 12.sp),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
