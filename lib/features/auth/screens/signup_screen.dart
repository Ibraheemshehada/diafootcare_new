import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_svg/svg.dart';

import '../widgets/signup_form.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              SizedBox(height: 40.h),
              // Logo
              Material(
                elevation: 10,
                shape: const CircleBorder(),
                shadowColor: Colors.black.withOpacity(0.4),
                child: CircleAvatar(
                  radius: 75.r,
                  backgroundColor: theme.scaffoldBackgroundColor,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/svg/logo_light.svg',
                        height: 90.h,
                        width: 60.w,
                        fit: BoxFit.contain,
                      ),
                      SizedBox(height: 12.h),
                      RichText(
                        text: TextSpan(
                          text: tr('app_name_light'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.lightBlueAccent,
                            fontWeight: FontWeight.bold,
                          ),
                          children: [
                            TextSpan(
                              text: tr('app_name_dark'),
                              style: TextStyle(color: Colors.blue),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                tr('signup_title'), // Sign Up
                style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              Text(
                tr('signup_subtitle'),
                style: TextStyle(fontSize: 13.sp, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              const SignUpForm(),
            ],
          ),
        ),
      ),
    );
  }
}
