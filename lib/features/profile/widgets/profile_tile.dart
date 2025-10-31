import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ProfileTile extends StatelessWidget {
  final IconData leading;
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? color;
  const ProfileTile({super.key, required this.leading, required this.title, this.onTap, this.trailing, this.color});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: t.cardColor,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: t.colorScheme.outlineVariant.withOpacity(.30)),
          boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black12, offset: Offset(0, 6))],
        ),
        child: Row(
          children: [
            Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                color: (color ?? t.colorScheme.secondaryContainer),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(leading, color: t.colorScheme.onSecondaryContainer, size: 20.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(child: Text(title, style: t.textTheme.bodyLarge)),
            trailing ?? Icon(Icons.chevron_right_rounded, color: t.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
