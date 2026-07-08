import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/qol_entry.dart';
import '../../../data/models/sus_entry.dart';
import '../viewmodel/wellbeing_viewmodel.dart';
import 'qol_checkin_screen.dart';
import 'satisfaction_survey_screen.dart';
import 'sus_survey_screen.dart';

/// WCAG AA colour for a 0–10 QoL score where higher = worse burden.
Color qolScoreColor(num v, BuildContext context) {
  final c = AppColors.of(context);
  if (v <= 3) return c.success;
  if (v <= 6) return c.warning;
  return c.danger;
}

class WellbeingScreen extends StatelessWidget {
  const WellbeingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final vm = context.watch<WellbeingViewModel>();
    final locale = context.locale.toLanguageTag();
    final trend = vm.qolBurdenTrend();

    return Scaffold(
      appBar: AppBar(
        title: Text('wellbeing_title'.tr(), style: TextStyle(fontSize: 18.sp)),
        backgroundColor: t.scaffoldBackgroundColor,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            () => Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: '/wellbeing/qol-checkin'),
                builder: (_) => const QolCheckInScreen(),
              ),
            ),
        icon: const Icon(Icons.add),
        label: Text('wellbeing_new_checkin'.tr()),
      ),
      body:
          vm.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 90.h),
                children: [
                  _LatestQolCard(latest: vm.latestQol, locale: locale),
                  if (trend.length >= 2) ...[
                    SizedBox(height: 16.h),
                    Text(
                      'wellbeing_trend'.tr(),
                      style: t.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    _QolTrendChart(values: trend),
                  ],
                  SizedBox(height: 16.h),
                  _SatisfactionCard(latest: vm.latestSatisfaction),
                  SizedBox(height: 12.h),
                  _SusCard(latest: vm.latestSus),
                  SizedBox(height: 16.h),
                  if (vm.qolEntries.isNotEmpty) ...[
                    Text(
                      'wellbeing_history'.tr(),
                      style: t.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    ...vm.qolEntries.map(
                      (e) => _QolHistoryTile(
                        key: ValueKey(e.id),
                        entry: e,
                        locale: locale,
                        onDelete: () => vm.removeQol(e.id),
                      ),
                    ),
                  ],
                ],
              ),
    );
  }
}

class _LatestQolCard extends StatelessWidget {
  final QolEntry? latest;
  final String locale;
  const _LatestQolCard({required this.latest, required this.locale});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: t.colorScheme.primary.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child:
          latest == null
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'wellbeing_latest'.tr(),
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'wellbeing_empty'.tr(),
                    style: TextStyle(fontSize: 12.sp, color: t.hintColor),
                  ),
                ],
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'wellbeing_latest'.tr(),
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        intl.DateFormat.yMMMd(locale).format(latest!.dateTime),
                        style: TextStyle(fontSize: 12.sp, color: t.hintColor),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  _MetricRow(label: 'qol_pain'.tr(), value: latest!.pain),
                  SizedBox(height: 8.h),
                  _MetricRow(
                    label: 'qol_mobility'.tr(),
                    value: latest!.mobility,
                  ),
                  SizedBox(height: 8.h),
                  _MetricRow(
                    label: 'qol_emotional'.tr(),
                    value: latest!.emotional,
                  ),
                ],
              ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final int value; // 0..10
  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color = qolScoreColor(value, context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13.sp, color: t.colorScheme.onSurface),
          ),
        ),
        SizedBox(width: 10.w),
        SizedBox(
          width: 90.w,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6.r),
            child: LinearProgressIndicator(
              value: value / 10,
              minHeight: 6.h,
              backgroundColor: t.dividerColor.withValues(alpha: .3),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Text(
          '$value/10',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _QolTrendChart extends StatelessWidget {
  final List<double> values; // oldest → newest, 0..10
  const _QolTrendChart({required this.values});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final n = values.length;
    final spots = List<FlSpot>.generate(
      n,
      (i) => FlSpot(i.toDouble(), values[i]),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        height: 180.h,
        color: t.colorScheme.primary.withValues(alpha: .05),
        padding: EdgeInsets.fromLTRB(8.w, 14.h, 14.w, 10.h),
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (n - 1).toDouble(),
            minY: 0,
            maxY: 10,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 2,
              getDrawingHorizontalLine:
                  (y) => FlLine(
                    color: t.dividerColor.withValues(alpha: .3),
                    strokeWidth: 1,
                  ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26.w,
                  interval: 2,
                  getTitlesWidget:
                      (value, meta) => Text(
                        value.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: t.colorScheme.onSurface.withValues(alpha: .6),
                        ),
                      ),
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                barWidth: 3,
                color: t.colorScheme.primary,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: t.colorScheme.primary.withValues(alpha: .12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QolHistoryTile extends StatelessWidget {
  final QolEntry entry;
  final String locale;
  final VoidCallback onDelete;
  const _QolHistoryTile({
    super.key,
    required this.entry,
    required this.locale,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Dismissible(
      key: ValueKey('qol_dismiss_${entry.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20.w),
        margin: EdgeInsets.only(bottom: 10.h),
        decoration: BoxDecoration(
          color: AppColors.of(context).danger.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Icon(Icons.delete_outline, color: AppColors.of(context).danger),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return true;
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: t.cardColor,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: t.dividerColor.withValues(alpha: .3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                intl.DateFormat.yMMMd(locale).add_jm().format(entry.dateTime),
                style: TextStyle(fontSize: 12.sp, color: t.hintColor),
              ),
            ),
            _MiniScore(label: 'qol_pain_short'.tr(), value: entry.pain),
            SizedBox(width: 8.w),
            _MiniScore(label: 'qol_mobility_short'.tr(), value: entry.mobility),
            SizedBox(width: 8.w),
            _MiniScore(
              label: 'qol_emotional_short'.tr(),
              value: entry.emotional,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniScore extends StatelessWidget {
  final String label;
  final int value;
  const _MiniScore({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final color = qolScoreColor(value, context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: BoxConstraints(minWidth: 30.w, minHeight: 30.w),
          padding: EdgeInsets.all(6.w),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .14),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        SizedBox(height: 3.h),
        Text(
          label,
          style: TextStyle(fontSize: 12.sp, color: Theme.of(context).hintColor),
        ),
      ],
    );
  }
}

class _SatisfactionCard extends StatelessWidget {
  final SatisfactionEntry? latest;
  const _SatisfactionCard({required this.latest});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final avg =
        latest == null
            ? null
            : ((latest!.ease + latest!.usefulness + latest!.willingness) / 3.0);
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: t.dividerColor.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.reviews_outlined,
                color: t.colorScheme.primary,
                size: 22.sp,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'satisfaction_title'.tr(),
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (avg != null)
                Text(
                  '${avg.toStringAsFixed(1)}/5',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: t.colorScheme.primary,
                  ),
                ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            latest == null
                ? 'satisfaction_prompt'.tr()
                : 'satisfaction_thanks'.tr(),
            style: TextStyle(fontSize: 12.sp, color: t.hintColor),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      settings: const RouteSettings(
                        name: '/wellbeing/satisfaction',
                      ),
                      builder: (_) => const SatisfactionSurveyScreen(),
                    ),
                  ),
              icon: const Icon(Icons.edit_outlined),
              label: Text(
                latest == null
                    ? 'satisfaction_take'.tr()
                    : 'satisfaction_update'.tr(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// System Usability Scale card: shows the latest computed SUS score (0–100,
/// 68 = average benchmark) and opens the 10-item questionnaire.
class _SusCard extends StatelessWidget {
  final SusEntry? latest;
  const _SusCard({required this.latest});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final score = latest?.score;
    final ac = AppColors.of(context);
    final color =
        score == null
            ? t.colorScheme.primary
            : (score >= 68
                ? ac.success
                : (score >= 51 ? ac.warning : ac.danger));
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: t.dividerColor.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.speed_outlined,
                color: t.colorScheme.primary,
                size: 22.sp,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'sus_title'.tr(),
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (score != null)
                Text(
                  score.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            score == null ? 'sus_prompt'.tr() : susAdjectiveKey(score).tr(),
            style: TextStyle(fontSize: 12.sp, color: t.hintColor),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      settings: const RouteSettings(name: '/wellbeing/sus'),
                      builder: (_) => const SusSurveyScreen(),
                    ),
                  ),
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(latest == null ? 'sus_take'.tr() : 'sus_retake'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}
