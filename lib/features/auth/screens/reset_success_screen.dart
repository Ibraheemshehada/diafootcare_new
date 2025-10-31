import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../routes/app_routes.dart';

class ResetSuccessScreen extends StatelessWidget {
  final String email;  // <-- plain email
  final String code;   // <-- 6-digit code

  const ResetSuccessScreen({
    super.key,
    required this.email,
    required this.code,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          children: [
            SizedBox(height: 40.h),
            SvgPicture.asset(
              "assets/svg/password_reset.svg",
              height: 220.h,
            ),
            SizedBox(height: 40.h),
            Text(
              tr('password_reset_title'),
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12.h),
            Text(
              tr('password_reset_subtitle'),
              style: TextStyle(fontSize: 13.sp, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.setPassword,
                    arguments: {
                      'email': email,
                      'code':  code,
                    },
                  );
                },
                child: Text(tr('confirm')),
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }
}
