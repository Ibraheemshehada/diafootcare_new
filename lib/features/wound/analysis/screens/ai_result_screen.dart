import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../chart_bounds.dart';
import '../viewmodel/analysis_result.dart';
import '../../../../data/repositories/wounds_repository.dart';
import '../../../../data/models/wound_entry.dart';

class AiResultScreen extends StatefulWidget {
  final AnalysisResult result;
  final String imagePath; // Image path to save
  const AiResultScreen({
    super.key,
    required this.result,
    required this.imagePath,
  });

  @override
  State<AiResultScreen> createState() => _AiResultScreenState();
}

class _AiResultScreenState extends State<AiResultScreen> {
  List<WoundEntry>? _historyEntries;
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistoryData();
  }

  Future<void> _loadHistoryData() async {
    try {
      final repo = WoundsRepository();
      final entries = await repo.loadAllWounds();
      // Sort by date ascending for chart
      entries.sort((a, b) => a.date.compareTo(b.date));

      if (mounted) {
        setState(() {
          _historyEntries = entries;
          _loadingHistory = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading history data: $e');
      if (mounted) {
        setState(() {
          _loadingHistory = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final primary = t.colorScheme.primary;
    const warn = Color(0xFFE8A317); // amber for a single positive condition
    final result = widget.result;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ai_wound_analysis'.tr(),
          style: TextStyle(fontSize: 18.sp),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
          children: [
            _SectionTitle('measurements'.tr()),
            SizedBox(height: 12.h),

            if (!result.isFromModel) ...[
              _Banner(
                icon: Icons.warning_amber_rounded,
                color: AppColors.of(context).danger,
                message: 'ai_demo_result_banner'.tr(),
              ),
              SizedBox(height: 12.h),
            ],

            if (!result.isCalibrated && result.isFromModel) ...[
              _Banner(
                icon: Icons.info_outline,
                color: AppColors.of(context).warning,
                message: 'ai_not_calibrated_banner'.tr(),
              ),
              SizedBox(height: 12.h),
            ],

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
              // Depth cannot be read from a 2D photo; it is only shown when the
              // clinician entered a probe measurement. 0 = not measured.
              valueText: result.depth > 0 ? null : '—',
              label: 'depth'.tr(),
              color: primary,
              unit: result.depth > 0 ? 'cm'.tr() : '',
            ),

            SizedBox(height: 20.h),
            _RiskBadge(badge: result.riskBadge),
            SizedBox(height: 16.h),
            _SectionTitle('wound_details'.tr()),
            SizedBox(height: 12.h),

            _DetailCard(
              svgAsset: 'assets/svg/micro.svg',
              title:
                  result
                      .tissueType, // keep value as-is to avoid missing-key warnings
              subtitle: 'tissue_type'.tr(),
              color: primary,
            ),
            SizedBox(height: 10.h),
            // Model 3 — replaces the old "Pus Level" row with two rows.
            _DetailCard(
              icon: Icons.coronavirus_outlined,
              title: _localizedStatus(result.infection),
              subtitle: 'infection'.tr(),
              color: result.infection == 'Present' ? warn : primary,
            ),
            SizedBox(height: 10.h),
            _DetailCard(
              icon: Icons.bloodtype_outlined,
              title: _localizedStatus(result.ischaemia),
              subtitle: 'blood_flow'.tr(),
              color: result.ischaemia == 'Impaired' ? warn : primary,
            ),

            SizedBox(height: 20.h),
            _SectionTitle('progress_summary'.tr()),
            SizedBox(height: 12.h),

            _ProgressSummaryCard(
              currentResult: result,
              historyEntries: _historyEntries ?? [],
            ),

            SizedBox(height: 20.h),
            _SectionTitle('progress_graph'.tr()),
            SizedBox(height: 12.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: _ProgressChart(
                currentResult: result,
                historyEntries: _historyEntries ?? [],
                isLoading: _loadingHistory,
              ),
            ),

            SizedBox(height: 28.h),
            ConstrainedBox(
              // minHeight (not an exact height): keeps the >=48dp touch
              // target while letting the button grow when the user
              // enlarges the system font. An exact height clipped labels.
              constraints: BoxConstraints(minHeight: 52.h),
              child: FilledButton(
                onPressed: () async {
                  try {
                    // Show loading indicator
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder:
                            (_) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                      );
                    }

                    // Save result to database
                    final repo = WoundsRepository();
                    await repo.saveWoundResult(
                      imagePath: widget.imagePath,
                      result: widget.result,
                    );

                    if (context.mounted) {
                      Navigator.pop(context); // Close loading dialog

                      // Show success message
                      await showAppSuccess(context, 'result_saved'.tr());

                      // Navigate back to home
                      Navigator.popUntil(context, (r) => r.isFirst);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context); // Close loading dialog

                      await showAppError(context, 'save_error'.tr());
                    }
                  }
                },
                child: Text(
                  'save_result'.tr(),
                  style: TextStyle(fontSize: 16.sp),
                ),
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
    style: Theme.of(context).textTheme.titleLarge?.copyWith(
      fontSize: 20.sp,
      fontWeight: FontWeight.w700,
    ),
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

  /// Optional display override (e.g. '—' for a not-measured depth). When null,
  /// the numeric [value] is shown as usual.
  final String? valueText;

  const _StatCard({
    this.icon,
    this.svgAsset,
    required this.value,
    required this.label,
    required this.color,
    this.quarterTurns = 0,
    this.unit = 'cm',
    this.valueText,
    super.key,
  }) : assert(
         icon != null || svgAsset != null,
         'Provide either icon or svgAsset',
       );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    Widget leading =
        svgAsset != null
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
        border: Border.all(
          color: t.colorScheme.outlineVariant.withOpacity(.35),
        ),
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
                valueText ??
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
  }) : assert(
         icon != null || svgAsset != null,
         'You must provide either icon or svgAsset',
       );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: t.colorScheme.outlineVariant.withOpacity(.35),
        ),
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
              child:
                  svgAsset != null
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

/// Map a Model-3 English status value to a localized display string.
String _localizedStatus(String value) {
  switch (value) {
    case 'Present':
      return 'status_present'.tr();
    case 'Not Present':
      return 'status_not_present'.tr();
    case 'Impaired':
      return 'status_impaired'.tr();
    case 'Adequate':
      return 'status_adequate'.tr();
    default:
      return 'not_available'.tr();
  }
}

/// Top-of-results risk banner derived from the SAME Model-3 prediction.
/// none->Normal (green), infection/ischaemia only->amber, both->High Risk (red).
class _RiskBadge extends StatelessWidget {
  final String badge; // English key from AnalysisResult.riskBadge
  const _RiskBadge({required this.badge});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    late final Color color;
    late final IconData icon;
    late final String label;
    switch (badge) {
      case 'High Risk':
        color = const Color(0xFFD64545); // red
        icon = Icons.warning_amber_rounded;
        label = 'badge_high_risk'.tr();
        break;
      case 'Infection Detected':
        color = const Color(0xFFE8A317); // amber
        icon = Icons.coronavirus_outlined;
        label = 'badge_infection'.tr();
        break;
      case 'Impaired Blood Flow':
        color = const Color(0xFFE8A317); // amber
        icon = Icons.bloodtype_outlined;
        label = 'badge_ischaemia'.tr();
        break;
      default: // Normal
        color = const Color(0xFF2E9E6B); // green
        icon = Icons.check_circle_outline;
        label = 'badge_normal'.tr();
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withOpacity(.45)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              label,
              style: t.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 16.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Progress summary card showing comparison with previous entries
class _ProgressSummaryCard extends StatelessWidget {
  final AnalysisResult currentResult;
  final List<WoundEntry> historyEntries;

  const _ProgressSummaryCard({
    required this.currentResult,
    required this.historyEntries,
  });

  /// Calculate progress percentage compared to entry from one week ago
  double _calculateProgress() {
    if (historyEntries.isEmpty) {
      // No history - return the default progress from result
      return currentResult.healingProgress;
    }

    // Find entry from approximately one week ago (7 days)
    final now = DateTime.now();
    WoundEntry? weekAgoEntry;

    // Find the entry closest to one week ago (at least 7 days old)
    for (var entry in historyEntries.reversed) {
      final daysDiff = now.difference(entry.date).inDays;
      if (daysDiff >= 7) {
        // Find entry that's at least 7 days old, closest to 7 days
        weekAgoEntry = entry;
        break;
      }
    }

    // If no entry from exactly one week ago, use the oldest entry we have
    if (weekAgoEntry == null && historyEntries.isNotEmpty) {
      weekAgoEntry = historyEntries.first;
    }

    // If still no entry (shouldn't happen), use the most recent one
    if (weekAgoEntry == null) {
      weekAgoEntry = historyEntries.last;
    }

    final weekAgoArea = weekAgoEntry.lengthCm * weekAgoEntry.widthCm;
    final currentArea = currentResult.length * currentResult.width;

    if (weekAgoArea == 0) {
      return 0.0;
    }

    // Calculate percentage change (positive = improvement, negative = deterioration)
    final change = ((weekAgoArea - currentArea) / weekAgoArea) * 100;
    return change;
  }

  /// Get progress message
  String _getProgressMessage() {
    final progress = _calculateProgress();

    if (historyEntries.isEmpty) {
      return 'progress_since_last_week'.tr(
        namedArgs: {
          'percent': currentResult.healingProgress.toStringAsFixed(1),
        },
      );
    }

    final absProgress = progress.abs();
    final percentStr = absProgress.toStringAsFixed(1);

    if (progress > 0) {
      // Improvement - wound is getting smaller
      return 'progress_since_last_week'.tr(
        namedArgs: {'percent': '+$percentStr'},
      );
    } else if (progress < 0) {
      // Deterioration - wound is getting larger
      return 'progress_since_last_week'.tr(
        namedArgs: {'percent': '-$percentStr'},
      );
    } else {
      // No change
      return 'progress_since_last_week'.tr(namedArgs: {'percent': '0.0'});
    }
  }

  /// Get icon based on progress
  IconData _getProgressIcon() {
    final progress = _calculateProgress();
    if (progress > 0) {
      return Icons.trending_up_rounded;
    } else if (progress < 0) {
      return Icons.trending_down_rounded;
    } else {
      return Icons.trending_flat_rounded;
    }
  }

  /// Get color based on progress
  Color _getProgressColor(ThemeData theme) {
    final progress = _calculateProgress();
    if (progress > 0) {
      return Colors.green; // Improvement
    } else if (progress < 0) {
      return Colors.orange; // Deterioration
    } else {
      return theme.colorScheme.primary; // No change
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final progressColor = _getProgressColor(t);

    return _DetailCard(
      icon: _getProgressIcon(),
      title: _getProgressMessage(),
      subtitle: 'healing_progress'.tr(),
      color: progressColor,
    );
  }
}

/// Progress chart widget for AI result screen
class _ProgressChart extends StatelessWidget {
  final AnalysisResult currentResult;
  final List<WoundEntry> historyEntries;
  final bool isLoading;

  const _ProgressChart({
    required this.currentResult,
    required this.historyEntries,
    required this.isLoading,
  });

  /// Calculate wound area in mm² (for chart display)
  double _calculateArea(double lengthCm, double widthCm) {
    return (lengthCm * 10) * (widthCm * 10);
  }

  List<FlSpot> _generateDataPoints() {
    final dataPoints = <FlSpot>[];

    // Add historical entries
    int index = 0;
    for (var entry in historyEntries) {
      final area = _calculateArea(entry.lengthCm, entry.widthCm);
      dataPoints.add(FlSpot(index.toDouble(), area));
      index++;
    }

    // Add current result at the end
    final currentArea = _calculateArea(
      currentResult.length,
      currentResult.width,
    );
    dataPoints.add(FlSpot(index.toDouble(), currentArea));

    return dataPoints;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final primary = t.colorScheme.primary;

    if (isLoading) {
      return Container(
        height: 220.h,
        padding: EdgeInsets.all(12.w),
        color: t.colorScheme.surfaceVariant.withOpacity(.25),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final dataPoints = _generateDataPoints();

    if (dataPoints.isEmpty) {
      // Show only current result if no history
      final currentArea = _calculateArea(
        currentResult.length,
        currentResult.width,
      );
      final singlePoint = [FlSpot(0.0, currentArea)];
      // Guard against a zero-height range (currentArea == 0 -> maxY == 0),
      // which makes fl_chart divide by zero. See chartYBounds.
      final bounds = chartYBounds([currentArea]);

      return Container(
        height: 220.h,
        padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 12.h),
        color: t.colorScheme.surfaceVariant.withOpacity(.25),
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: 0,
            minY: bounds.min,
            maxY: bounds.max,
            gridData: FlGridData(show: false),
            titlesData: FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: singlePoint,
                isCurved: false,
                barWidth: 3,
                color: primary,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 5,
                      color: primary,
                      strokeWidth: 2,
                      strokeColor: t.colorScheme.surface,
                    );
                  },
                ),
                belowBarData: BarAreaData(show: false),
              ),
            ],
          ),
        ),
      );
    }

    // Calculate min/max for chart scaling. chartYBounds guarantees a
    // non-degenerate, finite range so fl_chart never divides by a zero span
    // (which produced "OVERFLOWED BY Infinity PIXELS" + a crash when every
    // recorded wound area was 0, e.g. uncalibrated 0×0 cm captures).
    final bounds = chartYBounds(dataPoints.map((spot) => spot.y));
    final double maxY = bounds.max;
    final double minY = bounds.min;

    final maxX =
        dataPoints.isNotEmpty ? (dataPoints.length - 1).toDouble() : 0.0;

    return Container(
      height: 220.h,
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 12.h),
      color: t.colorScheme.surfaceVariant.withOpacity(.25),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY > 0 ? maxY / 5 : 200,
            getDrawingHorizontalLine:
                (y) => FlLine(
                  color: t.dividerColor.withOpacity(.3),
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
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36.w,
                interval: maxY > 0 ? maxY / 5 : 400,
                getTitlesWidget:
                    (value, meta) => Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: t.colorScheme.onSurface.withOpacity(.6),
                      ),
                    ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: dataPoints.length <= 7,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt().clamp(0, dataPoints.length - 1);
                  if (idx < historyEntries.length) {
                    final entry = historyEntries[idx];
                    final month = entry.date.month;
                    final monthName = 'months_abbr.$month'.tr();
                    return Padding(
                      padding: EdgeInsets.only(top: 6.h),
                      child: Text(
                        monthName,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: t.colorScheme.onSurface.withOpacity(.7),
                        ),
                      ),
                    );
                  } else if (idx == historyEntries.length) {
                    // Current result
                    final now = DateTime.now();
                    final monthName = 'months_abbr.${now.month}'.tr();
                    return Padding(
                      padding: EdgeInsets.only(top: 6.h),
                      child: Text(
                        monthName,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: t.colorScheme.onSurface.withOpacity(.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems:
                  (items) =>
                      items.map((it) {
                        final isCurrent = it.barIndex == dataPoints.length - 1;
                        return LineTooltipItem(
                          '${'area_mm2'.tr(namedArgs: {'value': it.y.toStringAsFixed(0)})}\n${isCurrent ? 'current'.tr() : 'historical'.tr()}',
                          TextStyle(
                            color: t.colorScheme.onSurface,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList(),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: dataPoints,
              isCurved: true,
              barWidth: 3,
              color: primary,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  // Highlight current result (last point)
                  final isCurrent = index == dataPoints.length - 1;
                  return FlDotCirclePainter(
                    radius: isCurrent ? 5 : 3,
                    color: primary,
                    strokeWidth: isCurrent ? 2 : 1,
                    strokeColor: t.colorScheme.surface,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: primary.withOpacity(.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline advisory banner. Both the icon tint and the body text use the same
/// theme-aware semantic colour (see [AppColors]), so the pair keeps its >=4.5:1
/// text contrast against the faint tinted background in light *and* dark mode.
/// The previous hardcoded `Colors.red[900]` was unreadable on a dark card.
class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  const _Banner({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: .4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icon, color: color, size: 20.sp)),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              message,
              style: t.textTheme.bodySmall?.copyWith(
                fontSize: 12.sp,
                height: 1.4,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
