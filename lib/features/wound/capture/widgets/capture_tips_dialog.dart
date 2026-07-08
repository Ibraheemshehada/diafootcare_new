import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CaptureTipsDialog extends StatelessWidget {
  const CaptureTipsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'tips_title'.tr(),
              style: t.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 16.sp,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),

            _bullet('tip_well_lit'.tr(), t),
            _bullet('tip_distance'.tr(), t),
            _bullet('tip_center'.tr(), t),
            _bullet('tip_avoid_blur'.tr(), t),
            _bullet('tip_remove_bandage'.tr(), t),

            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: ConstrainedBox(
                    // minHeight (not an exact height): keeps the >=48dp touch
                    // target while letting the button grow when the user
                    // enlarges the system font. An exact height clipped labels.
                    constraints: BoxConstraints(minHeight: 44.h),
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop('ok'),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'ok'.tr(),
                          style: TextStyle(fontSize: 14.sp),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ConstrainedBox(
                    // minHeight (not an exact height): keeps the >=48dp touch
                    // target while letting the button grow when the user
                    // enlarges the system font. An exact height clipped labels.
                    constraints: BoxConstraints(minHeight: 44.h),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                      ),
                      onPressed: () => Navigator.of(context).pop('dont_show'),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'dont_show_again'.tr(),
                          style: TextStyle(fontSize: 14.sp),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bullet(String text, ThemeData t) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: TextStyle(fontSize: 14.sp)),
          Expanded(
            child: Text(
              text,
              style: t.textTheme.bodyMedium?.copyWith(fontSize: 14.sp),
            ),
          ),
        ],
      ),
    );
  }
}
