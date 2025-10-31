
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../routes/app_routes.dart';
import '../widgets/login_form.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:easy_localization/easy_localization.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(

      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 40.h),

              // Logo in Circle
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
              SizedBox(height: 10.h),
              Text(
                'login'.tr(),
                style: TextStyle(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'login_subtitle'.tr(),
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 10.h),

              // Login form
              const LoginForm(),

              SizedBox(height: 20.h),

              // Forgot Password Text
              InkWell(
                onTap: (){
                  Navigator.pushNamed(context, AppRoutes.forgetPassword);
                },
                child: Text(
                  tr('forgot_password'),
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.blue,

                  ),
                ),
              ),

              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),

      // ✅ Always visible Outlined Button at bottom
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
        child: OutlinedButton(
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.signup);
          },
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 14.h),
            // minimumSize: Size(double.infinity, 48.h),
          ),
          child: Text(
            tr('create_account'),
            style: TextStyle(fontSize: 12.sp),
          ),
        ),
      ),
    );
  }
}
