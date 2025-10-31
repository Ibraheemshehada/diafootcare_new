import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../viewmodel/set_password_viewmodel.dart';

class SetPasswordForm extends StatelessWidget {
  const SetPasswordForm({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SetPasswordViewModel>();

    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('new_password')),
          SizedBox(height: 8.h),
          TextFormField(
            controller: vm.newPasswordController,
            obscureText: !vm.isPasswordVisible,
            decoration: InputDecoration(
              hintText: tr('enter_new_password'),
              errorText: vm.newPasswordError != null ? tr(vm.newPasswordError!) : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
              suffixIcon: IconButton(
                icon: Icon(vm.isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                onPressed: vm.togglePasswordVisibility,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            ),
          ),
          SizedBox(height: 20.h),
          Text(tr('confirm_password')),
          SizedBox(height: 8.h),
          TextFormField(
            controller: vm.confirmPasswordController,
            obscureText: !vm.isPasswordVisible,
            decoration: InputDecoration(
              hintText: tr('re_enter_password'),
              errorText: vm.confirmPasswordError != null ? tr(vm.confirmPasswordError!) : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
              suffixIcon: IconButton(
                icon: Icon(vm.isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                onPressed: vm.togglePasswordVisibility,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            ),
          ),
          SizedBox(height: 24.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: vm.isLoading ? null : () => vm.updatePassword(context),
              style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14.h)),
              child: vm.isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(tr('update_password'), style: TextStyle(fontSize: 14.sp)),
            ),
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}
