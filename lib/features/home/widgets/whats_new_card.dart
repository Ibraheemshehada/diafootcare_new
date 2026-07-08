import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/light_theme.dart' show kPrimaryLight;

class WhatsNewCard extends StatelessWidget {
  final TimeOfDay? nextReminder;
  final String? nextReminderTitle;
  final int weeklyProgressPercent;
  final String? latestGlucoseText; // e.g. "132 mg/dL" (null = none logged)
  final String? latestGlucoseStatus; // localized status label
  final Color? latestGlucoseColor;
  final VoidCallback? onGlucoseTap;
  final String? dfuStatusLabel; // localized DFU risk label (null = no wound yet)
  final IconData? dfuStatusIcon;
  final Color? dfuStatusColor;
  final VoidCallback? onDfuTap;
  final String? nextAppointmentText; // e.g. "Podiatrist · Jul 12, 3:30 PM"
  final VoidCallback? onAppointmentTap;
  const WhatsNewCard({
    super.key,
    required this.nextReminder,
    this.nextReminderTitle,
    required this.weeklyProgressPercent,
    this.latestGlucoseText,
    this.latestGlucoseStatus,
    this.latestGlucoseColor,
    this.onGlucoseTap,
    this.dfuStatusLabel,
    this.dfuStatusIcon,
    this.dfuStatusColor,
    this.onDfuTap,
    this.nextAppointmentText,
    this.onAppointmentTap,
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
                    kPrimaryLight.withOpacity(.95),
                    kPrimaryLight,
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
                        // srcIn (not srcATop): REPLACE the artwork's own fills
                        // with a faint white tint. srcATop only layered 1% white
                        // over the art, leaving its opaque #AED1FF shapes to show
                        // through — white title text on those measured 1.57:1
                        // (WCAG AA needs 4.5:1). srcIn keeps it a subtle
                        // silhouette that never competes with the text.
                        colorFilter: ColorFilter.mode(
                          Colors.white.withOpacity(0.07),
                          BlendMode.srcIn,
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
                        // srcIn (not srcATop): REPLACE the artwork's own fills
                        // with a faint white tint. srcATop only layered 1% white
                        // over the art, leaving its opaque #AED1FF shapes to show
                        // through — white title text on those measured 1.57:1
                        // (WCAG AA needs 4.5:1). srcIn keeps it a subtle
                        // silhouette that never competes with the text.
                        colorFilter: ColorFilter.mode(
                          Colors.white.withOpacity(0.07),
                          BlendMode.srcIn,
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
                                    ? 'home_next_reminder'.tr(namedArgs: {
                                        'title': nextReminderTitle ??
                                            'type_other'.tr(),
                                        'time': nextReminder!.format(context),
                                      })
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
                        if (latestGlucoseText != null) ...[
                          SizedBox(height: 8.h),
                          InkWell(
                            onTap: onGlucoseTap,
                            child: Row(
                              children: [
                                const Icon(Icons.water_drop_outlined,
                                    color: Colors.white),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    '${'glucose_title'.tr()}: $latestGlucoseText'
                                    '${latestGlucoseStatus != null ? ' · $latestGlucoseStatus' : ''}',
                                    style: t.textTheme.bodyMedium
                                        ?.copyWith(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (dfuStatusLabel != null) ...[
                          SizedBox(height: 8.h),
                          InkWell(
                            onTap: onDfuTap,
                            child: Row(
                              children: [
                                Icon(dfuStatusIcon ?? Icons.health_and_safety_outlined,
                                    color: dfuStatusColor ?? Colors.white),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      text: '${'home_foot_status'.tr()}: ',
                                      style: t.textTheme.bodyMedium
                                          ?.copyWith(color: Colors.white),
                                      children: [
                                        TextSpan(
                                          text: dfuStatusLabel,
                                          style: t.textTheme.bodyMedium?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (nextAppointmentText != null) ...[
                          SizedBox(height: 8.h),
                          InkWell(
                            onTap: onAppointmentTap,
                            child: Row(
                              children: [
                                const Icon(Icons.event_outlined,
                                    color: Colors.white),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    '${'appt_next'.tr()}: $nextAppointmentText',
                                    style: t.textTheme.bodyMedium
                                        ?.copyWith(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
