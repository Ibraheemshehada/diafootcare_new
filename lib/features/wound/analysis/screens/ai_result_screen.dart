import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../chart_bounds.dart';
import '../viewmodel/analysis_result.dart';
import '../services/infection_triage.dart';
import '../../../../data/repositories/wounds_repository.dart';
import '../../../../data/models/wound_entry.dart';

class AiResultScreen extends StatefulWidget {
  final AnalysisResult result;
  final String imagePath; // Image path to save

  /// Patient-reported signs from the checklist; null when it was skipped.
  final InfectionSigns? signs;

  const AiResultScreen({
    super.key,
    required this.result,
    required this.imagePath,
    this.signs,
  });

  @override
  State<AiResultScreen> createState() => _AiResultScreenState();
}

class _AiResultScreenState extends State<AiResultScreen> {
  List<WoundEntry>? _historyEntries;
  bool _loadingHistory = true;

  /// The model reports 0 when it found no wound. Sub-millimetre is the same
  /// thing: no ulcer is 0.4 mm across, so a figure that small is a failed
  /// segmentation dressed as a measurement.
  bool get _hasMeasurement =>
      widget.result.length > 0.05 && widget.result.width > 0.0;

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

            // Restored 2026-08-05. It was removed when scale calibration left
            // the flow, because it pointed at a step the user could no longer
            // reach. But without a scale reference the cm figures come from an
            // assumed 12 cm frame width, so they scale with however far the
            // camera happened to be held — a real patient wound of 1.4 cm was
            // reported as 0.9 cm. Presenting that to two decimal places with no
            // qualification overstates what the app knows. The wording now
            // states the limitation and points at the signal that IS reliable
            // (the trend) rather than an action that does not exist yet; it will
            // point at the calibration sticker once that ships.
            // See docs/ACCURACY_IMPROVEMENT_PLAN.md §2.
            if (result.captureAngle == CaptureAngle.poor ||
                result.captureAngle == CaptureAngle.marginal) ...[
              // Tilt is recorded with the result, not only warned about at
              // capture: whoever reads this later needs to know the photograph
              // was taken at an angle where measured error triples.
              _Banner(
                icon: Icons.screen_rotation_alt_rounded,
                color: AppColors.of(context).warning,
                message: 'ai_tilt_warning'.tr(
                    args: [(result.tiltDeg ?? 0).round().toString()]),
              ),
              SizedBox(height: 12.h),
            ],

            if (!result.isCalibrated) ...[
              _Banner(
                icon: Icons.straighten_rounded,
                color: AppColors.of(context).warning,
                message: 'ai_not_calibrated_banner'.tr(),
              ),
              SizedBox(height: 12.h),
            ],

            // A zero measurement is not a measurement. The model returns 0 when
            // it found no wound at all — and since the label guard shipped, that
            // happens more often: on 6 of 157 clinic photographs the printed
            // sticker was the only thing it found. "0.00 cm" reads as a healed
            // wound; saying nothing was found is the truth and is safer.
            if (!_hasMeasurement) ...[
              _Banner(
                icon: Icons.search_off_rounded,
                color: AppColors.of(context).warning,
                message: 'ai_no_wound_found'.tr(),
              ),
              SizedBox(height: 12.h),
            ] else ...[
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
              icon: Icons.crop_free,
              value: result.area,
              label: 'area'.tr(),
              color: primary,
              unit: 'cm2'.tr(),
            ),
            ],

            // What the model actually saw. Until this existed the app reported
            // a size with nothing behind it, and a clinician could not tell a
            // correct measurement from one taken off the printed label — which
            // happened in 16 of 42 small-label photographs.
            if (result.overlayImagePath != null) ...[
              SizedBox(height: 14.h),
              _WoundOverlayCard(path: result.overlayImagePath!),
            ],

            // The depth row was removed: a 2D photo cannot measure depth, and
            // the manual-entry step that used to supply it is gone from the
            // capture flow. Length and width are what the model produces.
            SizedBox(height: 20.h),
            // Derived from the SAME triage the card below shows, not from
            // Model 3's raw 0.41 cut-off. Those were two independent judges and
            // they contradicted each other on screen — the badge said
            // "Infection detected" while the card said "no signs", for one
            // wound, in one analysis. See docs/CONTRADICTORY_VERDICT_INVESTIGATION.md.
            // result.riskBadge is still stored and synced: the dashboard needs
            // what Model 3 alone reported. It just no longer speaks to the
            // patient without the checklist beside it.
            _RiskBadge(
              outcome: triage(
                infectionProbability: result.infectionProbability,
                signs: widget.signs ?? const InfectionSigns(),
              ).outcome,
              ischaemia: result.ischaemia == 'Impaired',
            ),
            SizedBox(height: 16.h),
            _SectionTitle('wound_details'.tr()),
            SizedBox(height: 12.h),

            _DetailCard(
              svgAsset: 'assets/svg/micro.svg',
              // Every tissue present, most serious first, rather than one
              // headline — a wound bed usually holds more than one, and the
              // rest of the answer used to be discarded.
              title: result.localizedTissueSummary,
              subtitle: 'tissue_type'.tr(),
              color: primary,
            ),
            if (result.tissueFindings.isNotEmpty) ...[
              SizedBox(height: 10.h),
              TissueBreakdown(findings: result.tissueFindings),
            ],
            SizedBox(height: 10.h),
            // Model 3. The bare 'Present'/'Not Present' row is replaced by the
            // IWGDF/IDSA triage: the image score is banded (low / uncertain /
            // high) and combined with the patient's reported signs, because a
            // single cut-off on a 0.74-specificity signal produced alarms that
            // were wrong more often than right at clinic prevalence.
            // See docs/IMPLEMENTATION_TRACKER.md §C4.
            _TriageCard(
              result: triage(
                infectionProbability: result.infectionProbability,
                signs: widget.signs ?? const InfectionSigns(),
              ),
              answered: widget.signs != null,
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
          // Expanded so a long value has somewhere to wrap. The tissue row now
          // carries every tissue found — "Necrosis, Slough, Granulation,
          // Callus" — where it once held a single word, and an unbounded
          // Column simply ran off the edge of the card.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title, // keep raw value (from AI result)
                  style: t.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16.sp,
                  ),
                  // Two lines fits every combination of the five tissue
                  // classes; past that the value is truncated rather than
                  // pushing the card taller than the rows around it.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
  /// The triage outcome — the single source of truth for what the patient is
  /// told. Never Model 3's raw binary.
  final TriageOutcome outcome;

  /// Impaired blood flow is a separate finding from infection and is not part
  /// of the infection triage, so it is carried alongside rather than folded in.
  final bool ischaemia;

  const _RiskBadge({required this.outcome, required this.ischaemia});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = AppColors.of(context);

    late final Color color;
    late final IconData icon;
    late final String label;
    String? action;

    switch (outcome) {
      case TriageOutcome.urgent:
        color = c.danger;
        icon = Icons.emergency_outlined;
        label = 'badge_urgent'.tr();
        action = 'badge_action_urgent'.tr();
      case TriageOutcome.seeClinician:
        color = c.warning;
        // The clinician asked for the evidence to be named, not just the
        // verdict: "Infection detected (signs of inflammation present)".
        icon = Icons.coronavirus_outlined;
        label = 'badge_infection_signs'.tr();
        action = 'badge_action_clinic'.tr();
      case TriageOutcome.recheckPhoto:
        color = c.caution;
        icon = Icons.photo_camera_outlined;
        label = 'badge_recheck'.tr();
        action = 'badge_action_recheck'.tr();
      case TriageOutcome.monitor:
        color = c.caution;
        icon = Icons.visibility_outlined;
        label = 'badge_monitor'.tr();
        action = 'badge_action_monitor'.tr();
      case TriageOutcome.noSigns:
        // Ischaemia is judged separately, so a wound with no infection signs
        // but impaired flow must not be shown as simply "normal".
        color = ischaemia ? c.warning : c.success;
        icon = ischaemia ? Icons.bloodtype_outlined : Icons.check_circle_outline;
        label = ischaemia ? 'badge_ischaemia'.tr() : 'badge_normal'.tr();
        action = ischaemia ? 'badge_action_clinic'.tr() : null;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22.sp),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  label,
                  style: t.textTheme.titleSmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (action != null) ...[
            SizedBox(height: 6.h),
            Text(action, style: t.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
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

  /// Wound area in mm² for chart display. Prefers the true segmented area
  /// (cm² → mm²) and falls back to the length × width bounding rectangle for
  /// records that predate stored area.
  double _areaMm2({double? areaCm2, required double lengthCm, required double widthCm}) {
    if (areaCm2 != null && areaCm2 > 0) return areaCm2 * 100;
    return (lengthCm * 10) * (widthCm * 10);
  }

  List<FlSpot> _generateDataPoints() {
    final dataPoints = <FlSpot>[];

    // Add historical entries
    int index = 0;
    for (var entry in historyEntries) {
      final area = _areaMm2(
        areaCm2: entry.areaCm2,
        lengthCm: entry.lengthCm,
        widthCm: entry.widthCm,
      );
      dataPoints.add(FlSpot(index.toDouble(), area));
      index++;
    }

    // Add current result at the end
    final currentArea = _areaMm2(
      areaCm2: currentResult.area,
      lengthCm: currentResult.length,
      widthCm: currentResult.width,
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
      final currentArea = _areaMm2(
        areaCm2: currentResult.area,
        lengthCm: currentResult.length,
        widthCm: currentResult.width,
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

/// Every tissue class the model considered, and whether it found it.
///
/// The confidence figures used to be here — a bar and a percentage per class,
/// with a note explaining that each class has its own tuned threshold. They
/// were removed: clinicians and patients read "Necrosis 36%" as *some
/// necrosis*, when it means *not necrosis*. A number under its threshold and a
/// number over it look alike, and the one thing that separates them was the
/// sentence nobody read.
///
/// So the finding is stated and the arithmetic behind it is not. Classes that
/// were not found are still listed, greyed — absence stated rather than implied
/// by omission, which is the part that was never confusing.
///
/// The probabilities are still recorded and still synced; they belong in the
/// study data, not on a screen someone reads over a patient's foot.
class TissueBreakdown extends StatelessWidget {
  final List<TissueFinding> findings;

  const TissueBreakdown({super.key, required this.findings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [...findings]
      ..sort((a, b) => b.probability.compareTo(a.probability));

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('tissue_breakdown'.tr(),
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          SizedBox(height: 10.h),
          for (final f in sorted) ...[
            Row(
              children: [
                // Presence is carried by the icon and the text weight, not by
                // colour alone.
                Icon(
                  f.isPresent ? Icons.check_circle : Icons.remove_circle_outline,
                  size: 16.sp,
                  color: f.isPresent
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    f.localizedName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          f.isPresent ? FontWeight.w600 : FontWeight.w400,
                      color: f.isPresent
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                // The verdict in words, so the row does not depend on reading
                // an icon: "Found" / "Not found".
                Text(
                  (f.isPresent ? 'tissue_found' : 'tissue_not_found').tr(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: f.isPresent ? FontWeight.w600 : FontWeight.w400,
                    color: f.isPresent
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
          ],
          Text('tissue_note'.tr(),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Renders the IWGDF/IDSA triage outcome.
///
/// Deliberately not a bare yes/no: the middle band says "uncertain" out loud
/// rather than guessing, and the deep-infection caveat rides along with every
/// non-urgent outcome because neither a photograph nor this checklist can see
/// osteomyelitis — "no signs" must never read as an all-clear.
class _TriageCard extends StatelessWidget {
  final TriageResult result;

  /// False when the checklist was skipped, so the card can say the answer is
  /// based on the photograph alone rather than implying a full assessment.
  final bool answered;

  const _TriageCard({required this.result, required this.answered});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = Theme.of(context);

    late final Color colour;
    late final IconData icon;
    late final String titleKey;
    late final String bodyKey;
    switch (result.outcome) {
      case TriageOutcome.urgent:
        colour = c.danger;
        icon = Icons.emergency_outlined;
        titleKey = 'infection_out_urgent';
        bodyKey = 'infection_out_urgent_body';
      case TriageOutcome.seeClinician:
        colour = c.warning;
        icon = Icons.medical_services_outlined;
        titleKey = 'infection_out_clinician';
        bodyKey = 'infection_out_clinician_body';
      case TriageOutcome.recheckPhoto:
        colour = c.caution;
        icon = Icons.photo_camera_outlined;
        titleKey = 'infection_out_recheck';
        bodyKey = 'infection_out_recheck_body';
      case TriageOutcome.monitor:
        colour = c.caution;
        icon = Icons.visibility_outlined;
        titleKey = 'infection_out_monitor';
        bodyKey = 'infection_out_monitor_body';
      case TriageOutcome.noSigns:
        colour = c.success;
        icon = Icons.check_circle_outline;
        titleKey = 'infection_out_none';
        bodyKey = 'infection_out_none_body';
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.10),
        border: Border.all(color: colour.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colour, size: 24.sp),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  titleKey.tr(),
                  style: t.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colour,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(bodyKey.tr(), style: t.textTheme.bodyMedium),
          if (!answered) ...[
            SizedBox(height: 8.h),
            Text(
              'infection_check_skipped'.tr(),
              style: t.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
          if (result.needsDeepInfectionCaveat) ...[
            SizedBox(height: 10.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16.sp, color: t.hintColor),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    deepInfectionCaveatKey.tr(),
                    style: t.textTheme.bodySmall?.copyWith(color: t.hintColor),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The photograph with the measured region drawn on it.
///
/// Tappable to full screen, because the whole point is to be looked at closely:
/// an under-segmented boundary and a correct one differ by a few millimetres on
/// a phone-sized thumbnail.
class _WoundOverlayCard extends StatelessWidget {
  final String path;
  const _WoundOverlayCard({required this.path});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final file = File(path);
    if (!file.existsSync()) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ai_overlay_title'.tr(),
          style: t.textTheme.titleSmall
              ?.copyWith(fontSize: 14.sp, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 4.h),
        Text(
          'ai_overlay_hint'.tr(),
          style: t.textTheme.bodySmall?.copyWith(
            fontSize: 12.sp,
            color: t.colorScheme.onSurface.withValues(alpha: .7),
          ),
        ),
        SizedBox(height: 8.h),
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  title: Text('ai_overlay_title'.tr(),
                      style: TextStyle(fontSize: 16.sp)),
                ),
                body: Center(
                  child: InteractiveViewer(
                    maxScale: 6,
                    child: Image.file(file),
                  ),
                ),
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: Image.file(
              file,
              width: double.infinity,
              fit: BoxFit.cover,
              // Rebuilt per scan, so a cached decode from the previous wound
              // would show the wrong photograph entirely.
              key: ValueKey(path),
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}
