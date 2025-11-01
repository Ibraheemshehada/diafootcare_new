import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';

import '../viewmodel/analysis_result.dart';
import '../../../../data/repositories/wounds_repository.dart';

class AiResultScreen extends StatelessWidget {
  final AnalysisResult result;
  final String imagePath; // Image path to save
  const AiResultScreen({super.key, required this.result, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final primary = t.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text('ai_wound_analysis'.tr(), style: TextStyle(fontSize: 18.sp)),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
          children: [
            _SectionTitle('measurements'.tr()),
            SizedBox(height: 12.h),

            _StatCard(
              icon: Icons.straighten,
              value: result.length,
              label: 'length'.tr(),
              color: primary,
              quarterTurns: 1,
              unit: 'cm'.tr(),
            ),
            SizedBox(height: 10.h),
            _StatCard(
              icon: Icons.straighten,
              value: result.width,
              label: 'width'.tr(),
              color: primary,
              unit: 'cm'.tr(),
            ),
            SizedBox(height: 10.h),
            _StatCard(
              svgAsset: 'assets/svg/arrow_down.svg',
              value: result.depth,
              label: 'depth'.tr(),
              color: primary,
              unit: 'cm'.tr(),
            ),

            SizedBox(height: 20.h),
            _SectionTitle('wound_details'.tr()),
            SizedBox(height: 12.h),

            _DetailCard(
              svgAsset: 'assets/svg/micro.svg',
              title: result.tissueType,              // keep value as-is to avoid missing-key warnings
              subtitle: 'tissue_type'.tr(),
              color: primary,
            ),
            SizedBox(height: 10.h),
            _DetailCard(
              icon: Icons.opacity_outlined,
              title: result.pusLevel,
              subtitle: 'pus_level'.tr(),
              color: primary,
            ),
            SizedBox(height: 10.h),
            _DetailCard(
              icon: Icons.local_fire_department_outlined,
              title: result.inflammation,
              subtitle: 'inflammation'.tr(),
              color: primary,
            ),

            SizedBox(height: 20.h),
            _SectionTitle('progress_summary'.tr()),
            SizedBox(height: 12.h),

            _DetailCard(
              icon: Icons.trending_up_rounded,
              title: 'progress_since_last_week'.tr(namedArgs: {
                'percent': result.healingProgress.toString(),
              }),
              subtitle: 'healing_progress'.tr(),
              color: primary,
            ),

            SizedBox(height: 20.h),
            _SectionTitle('progress_graph'.tr()),
            SizedBox(height: 12.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: Image.asset(result.graphImagePath, fit: BoxFit.contain),
            ),

            SizedBox(height: 28.h),
            SizedBox(
              height: 52.h,
              child: FilledButton(
                onPressed: () async {
                  try {
                    // Show loading indicator
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(child: CircularProgressIndicator()),
                      );
                    }

                    // Save result to database
                    final repo = WoundsRepository();
                    await repo.saveWoundResult(
                      imagePath: imagePath,
                      result: result,
                    );

                    if (context.mounted) {
                      Navigator.pop(context); // Close loading dialog
                      
                      // Show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('result_saved'.tr()),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );

                      // Navigate back to home
                      Navigator.popUntil(context, (r) => r.isFirst);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context); // Close loading dialog
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('save_error'.tr()),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                },
                child: Text('save_result'.tr(), style: TextStyle(fontSize: 16.sp)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------- shared section title ---------- */
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context)
        .textTheme
        .titleLarge
        ?.copyWith(fontSize: 20.sp, fontWeight: FontWeight.w700),
  );
}

/* ---------- StatCard ---------- */
class _StatCard extends StatelessWidget {
  final IconData? icon;
  final String? svgAsset;
  final double value;
  final String label;
  final Color color;
  final int quarterTurns;
  final String unit;

  const _StatCard({
    this.icon,
    this.svgAsset,
    required this.value,
    required this.label,
    required this.color,
    this.quarterTurns = 0,
    this.unit = 'cm',
    super.key,
  }) : assert(icon != null || svgAsset != null, 'Provide either icon or svgAsset');

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    Widget leading = svgAsset != null
        ? SvgPicture.asset(
      svgAsset!,
      width: 22.w,
      height: 22.w,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    )
        : Icon(icon, size: 22.sp, color: color);
    leading = RotatedBox(quarterTurns: quarterTurns, child: leading);

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: t.colorScheme.outlineVariant.withOpacity(.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: color.withOpacity(.08),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Center(child: leading),
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${value.toStringAsFixed(1)} ${unit.isEmpty ? "" : unit}',
                style: t.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 16.sp,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                label,
                style: t.textTheme.bodySmall?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ---------- DetailCard ---------- */
class _DetailCard extends StatelessWidget {
  final IconData? icon;
  final String? svgAsset;
  final String title;
  final String subtitle;
  final Color color;

  const _DetailCard({
    this.icon,
    this.svgAsset,
    required this.title,
    required this.subtitle,
    required this.color,
    super.key,
  }) : assert(icon != null || svgAsset != null, 'You must provide either icon or svgAsset');

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: t.colorScheme.outlineVariant.withOpacity(.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: color.withOpacity(.08),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Center(
              child: svgAsset != null
                  ? SvgPicture.asset(
                svgAsset!,
                width: 22.w,
                height: 22.w,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              )
                  : Icon(icon, size: 22.sp, color: color),
            ),
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title, // keep raw value (from AI result)
                style: t.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 16.sp,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                subtitle,
                style: t.textTheme.bodySmall?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
