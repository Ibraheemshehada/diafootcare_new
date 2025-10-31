import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../routes/app_routes.dart';

class ConfirmCodeScreen extends StatelessWidget {
  final String maskedEmail;
  final String email; // <-- add plain email
  const ConfirmCodeScreen({
    super.key,
    required this.maskedEmail,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              SizedBox(height: 40.h),
              SizedBox(height: 20.h),
              Text(
                tr('confirmScreen_title'),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp),
              ),
              SizedBox(height: 8.h),
              Text(
                maskedEmail,
                style: TextStyle(fontSize: 14.sp, color: Colors.grey),
              ),
              SizedBox(height: 40.h),
              Padding(
                padding: const EdgeInsets.only(bottom: 100),
                child: SvgPicture.asset(
                  'assets/svg/email_check.svg',
                  height: 180.h,
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.otp,
                      arguments: {
                        'email': email,        // pass plain email
                        'masked': maskedEmail, // pass masked email
                      },
                    );
                  },
                  child: Text(tr('continue')),
                ),
              ),
              SizedBox(height: 30.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(tr('back')),
                ),
              ),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }
}
