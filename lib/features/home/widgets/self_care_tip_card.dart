import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../data/models/self_care_task.dart';

/// Home dashboard summary for the Self-Care feature: today's completion +
/// streak, plus a rotating Do/Don't tip (chosen once per app launch in
/// [SelfCareViewModel]). Tapping the card opens the full Self-Care screen.
class SelfCareTipCard extends StatelessWidget {
  final SelfCareTip tip;
  final int doneToday;
  final int totalTasks;
  final int streak;
  final VoidCallback onTap;
  const SelfCareTipCard({
    super.key,
    required this.tip,
    required this.doneToday,
    required this.totalTasks,
    required this.streak,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final primary = t.colorScheme.primary;
    final isDo = tip.isDo;
    final accent = isDo ? Colors.green.shade600 : Colors.red.shade600;
    final badgeIcon = isDo ? Icons.check_circle : Icons.cancel;
    final badgeLabel =
        isDo ? 'selfcare_do_title'.tr() : 'selfcare_dont_title'.tr();
    final progress = totalTasks == 0 ? 0.0 : doneToday / totalTasks;

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 4.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18.r),
          child: Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: primary.withValues(alpha: .16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- Status zone: title + streak + chevron ----
                Row(
                  children: [
                    Container(
                      width: 38.w,
                      height: 38.w,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: .12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.checklist_rounded,
                          color: primary, size: 20.sp),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text('selfcare_title'.tr(),
                          style: TextStyle(
                              fontSize: 15.sp, fontWeight: FontWeight.w800)),
                    ),
                    if (streak > 0) ...[
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_fire_department,
                                size: 14.sp, color: Colors.deepOrange),
                            SizedBox(width: 3.w),
                            Text(
                              'selfcare_streak'
                                  .tr(namedArgs: {'days': streak.toString()}),
                              style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.deepOrange),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 4.w),
                    ],
                    Icon(isRtl ? Icons.chevron_left : Icons.chevron_right,
                        color: t.hintColor, size: 22.sp),
                  ],
                ),
                SizedBox(height: 12.h),
                // ---- Progress bar + count ----
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.r),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 7.h,
                          backgroundColor: t.dividerColor.withValues(alpha: .3),
                          valueColor: AlwaysStoppedAnimation(
                              progress >= 1 ? Colors.green.shade600 : primary),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Text('$doneToday/$totalTasks',
                        style: TextStyle(
                            fontSize: 12.sp, fontWeight: FontWeight.w700)),
                  ],
                ),
                SizedBox(height: 12.h),
                Divider(height: 1, color: t.dividerColor.withValues(alpha: .3)),
                SizedBox(height: 12.h),
                // ---- Rotating tip ----
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline, color: primary, size: 18.sp),
                    SizedBox(width: 8.w),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 11.sp, color: accent),
                          SizedBox(width: 3.w),
                          Text(badgeLabel,
                              style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: accent)),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        tip.messageKey.tr(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5.sp,
                            height: 1.3,
                            color: t.colorScheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
