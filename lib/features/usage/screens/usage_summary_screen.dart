import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/services/analytics_service.dart';
import '../../../data/models/analytics_summary.dart';
import '../../../data/repositories/analytics_repository.dart';

class UsageSummaryScreen extends StatefulWidget {
  const UsageSummaryScreen({super.key});

  @override
  State<UsageSummaryScreen> createState() => _UsageSummaryScreenState();
}

class _UsageSummaryScreenState extends State<UsageSummaryScreen> {
  late final Future<AnalyticsSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = AnalyticsRepository().getSummary();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final locale = context.locale.toLanguageTag();

    return Scaffold(
      appBar: AppBar(title: Text('usage_title'.tr())),
      body: FutureBuilder<AnalyticsSummary>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final s = snap.data!;
          if (s.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(32.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.insights_outlined,
                        size: 64.sp, color: t.hintColor),
                    SizedBox(height: 16.h),
                    Text('usage_empty'.tr(),
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: t.hintColor, fontSize: 14.sp)),
                  ],
                ),
              ),
            );
          }

          final maxCount = s.features.isEmpty
              ? 1
              : s.features.map((f) => f.count).reduce((a, b) => a > b ? a : b);

          return ListView(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
            children: [
              Row(
                children: [
                  _StatCard(
                    icon: Icons.event_available_outlined,
                    value: '${s.activeDays}',
                    label: 'usage_active_days'.tr(),
                  ),
                  SizedBox(width: 10.w),
                  _StatCard(
                    icon: Icons.local_fire_department,
                    value: '${s.currentStreak}',
                    label: 'usage_streak'.tr(),
                    accent: Colors.deepOrange,
                  ),
                  SizedBox(width: 10.w),
                  _StatCard(
                    icon: Icons.login_outlined,
                    value: '${s.appOpens}',
                    label: 'usage_app_opens'.tr(),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              _InfoRow(
                icon: Icons.flag_outlined,
                label: 'usage_member_since'.tr(),
                value: s.firstUse == null
                    ? '—'
                    : intl.DateFormat.yMMMd(locale).format(s.firstUse!),
              ),
              SizedBox(height: 8.h),
              _InfoRow(
                icon: Icons.schedule_outlined,
                label: 'usage_last_active'.tr(),
                value: s.lastActive == null
                    ? '—'
                    : intl.DateFormat.yMMMd(locale)
                        .add_jm()
                        .format(s.lastActive!),
              ),
              SizedBox(height: 20.h),
              Text('usage_features'.tr(),
                  style: t.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              SizedBox(height: 10.h),
              if (s.features.isEmpty)
                Text('usage_no_features'.tr(),
                    style: TextStyle(fontSize: 13.sp, color: t.hintColor))
              else
                ...s.features.map((f) => _FeatureBar(
                      label: analyticsFeatureLabel(f.route),
                      count: f.count,
                      fraction: f.count / maxCount,
                    )),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? accent;
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color = accent ?? t.colorScheme.primary;
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 8.w),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24.sp),
            SizedBox(height: 8.h),
            Text(value,
                style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    color: color)),
            SizedBox(height: 2.h),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.sp, color: t.hintColor)),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18.sp, color: t.hintColor),
        SizedBox(width: 10.w),
        Text('$label: ',
            style: TextStyle(fontSize: 13.sp, color: t.hintColor)),
        Expanded(
          child: Text(value,
              style:
                  TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _FeatureBar extends StatelessWidget {
  final String label;
  final int count;
  final double fraction;
  const _FeatureBar({
    required this.label,
    required this.count,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.sp)),
              ),
              SizedBox(width: 8.w),
              Text('usage_times'.tr(namedArgs: {'count': '$count'}),
                  style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: t.colorScheme.primary)),
            ],
          ),
          SizedBox(height: 6.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(6.r),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.05, 1.0),
              minHeight: 7.h,
              backgroundColor: t.dividerColor.withValues(alpha: .3),
              valueColor:
                  AlwaysStoppedAnimation(t.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
