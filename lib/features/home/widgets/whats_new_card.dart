import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WhatsNewCard extends StatelessWidget {
  final TimeOfDay? nextReminder;
  final String? nextReminderTitle;
  final int weeklyProgressPercent;
  const WhatsNewCard({
    super.key,
    required this.nextReminder,
    this.nextReminderTitle,
    required this.weeklyProgressPercent,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: const [
          BoxShadow(blurRadius: 16, color: Colors.black12, offset: Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final h = c.maxHeight == double.infinity ? 140.h : c.maxHeight;

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xff077FFF).withOpacity(.95),
                    const Color(0xff077FFF),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    right: 0,
                    child: SizedBox(
                      width: .48 * w,
                      height: .48 * h,
                      child: SvgPicture.asset(
                        'assets/svg/whats_bg_top_right.svg',
                        fit: BoxFit.contain,
                        alignment: Alignment.topRight,
                        colorFilter: ColorFilter.mode(
                          Colors.white.withOpacity(0.01),
                          BlendMode.srcATop,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: SizedBox(
                      width: .80 * w,
                      height: .60 * h,
                      child: SvgPicture.asset(
                        'assets/svg/whats_bg_bottom_left.svg',
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomLeft,
                        colorFilter: ColorFilter.mode(
                          Colors.white.withOpacity(0.01),
                          BlendMode.srcATop,
                        ),
                      ),
                    ),
                  ),

                  // Content
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'whats_new_today'.tr(),
                          style: t.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            const Icon(Icons.alarm, color: Colors.white),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                nextReminder != null
                                    ? 'Next Reminder: ${nextReminderTitle ?? 'Reminder'} at ${nextReminder!.format(context)}'
                                    : 'no_upcoming_reminders'.tr(),
                                style: t.textTheme.bodyMedium?.copyWith(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            const Icon(Icons.trending_up, color: Colors.white),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                weeklyProgressPercent != 0
                                    ? 'last_week_progress'.tr(
                                        namedArgs: {
                                          'percent': weeklyProgressPercent > 0 
                                              ? '+${weeklyProgressPercent.toString()}' 
                                              : weeklyProgressPercent.toString(),
                                        },
                                      )
                                    : 'no_progress_data'.tr(),
                                style: t.textTheme.bodyMedium?.copyWith(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
