import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import '../viewmodel/signup_viewmodel.dart';

class SignUpForm extends StatelessWidget {
  const SignUpForm({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SignUpViewModel(),
      child: Consumer<SignUpViewModel>(
        builder: (context, vm, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Email
              Text(tr('email_or_mobile')),
              SizedBox(height: 8.h),
              TextFormField(
                controller: vm.emailController,
                decoration: InputDecoration(
                  hintText: tr('email_or_mobile'),
                  errorText: vm.emailError != null ? tr(vm.emailError!) : null,
                ),
              ),
              SizedBox(height: 16.h),

              // Full name
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('first_name')),
                        SizedBox(height: 8.h),
                        TextFormField(
                          controller: vm.firstNameController,
                          decoration: InputDecoration(
                            hintText: tr('first_name'),
                            errorText: vm.firstNameError != null ? tr(vm.firstNameError!) : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('last_name')),
                        SizedBox(height: 8.h),
                        TextFormField(
                          controller: vm.lastNameController,
                          decoration: InputDecoration(
                            hintText: tr('last_name'),
                            errorText: vm.lastNameError != null ? tr(vm.lastNameError!) : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // Password
              Text(tr('password')),
              SizedBox(height: 8.h),
              TextFormField(
                controller: vm.passwordController,
                obscureText: !vm.isPasswordVisible,
                decoration: InputDecoration(
                  hintText: tr('password'),
                  errorText: vm.passwordError != null ? tr(vm.passwordError!) : null,
                  suffixIcon: IconButton(
                    icon: Icon(vm.isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                    onPressed: vm.togglePasswordVisibility,
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Confirm Password
              Text(tr('confirm_password')),
              SizedBox(height: 8.h),
              TextFormField(
                controller: vm.confirmPasswordController,
                obscureText: !vm.isPasswordVisible,
                decoration: InputDecoration(
                  hintText: tr('confirm_password'),
                  errorText: vm.confirmPasswordError != null ? tr(vm.confirmPasswordError!) : null,
                  suffixIcon: IconButton(
                    icon: Icon(vm.isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                    onPressed: vm.togglePasswordVisibility,
                  ),
                ),
              ),
              SizedBox(height: 24.h),

              // Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: vm.isLoading ? null : () => vm.signUp(context),
                  child: vm.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(tr('create_account')),
                ),
              ),
              SizedBox(height: 12.h),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: RichText(
                    text: TextSpan(
                      text: tr('already_have_account_prefix') + ' ', // "Already have an account?"
                      style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                      children: [
                        TextSpan(
                          text: tr('login'),
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }
}
