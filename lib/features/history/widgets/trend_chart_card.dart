import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;

import '../viewmodel/history_viewmodel.dart';

class TrendChartCard extends StatelessWidget {
  /// Percent reductions of the average wound area, oldest → newest.
  final TrendSeries series;

  /// Currently selected granularity, and the callback to change it.
  final TrendRange range;
  final ValueChanged<TrendRange> onRangeChanged;

  const TrendChartCard({
    super.key,
    required this.series,
    required this.range,
    required this.onRangeChanged,
  });

  /// X-axis label for one bucket, at the current granularity.
  String _label(BuildContext context, DateTime bucketStart) {
    final locale = context.locale.toLanguageTag();
    switch (range) {
      case TrendRange.daily:
        // Short weekday, e.g. Mon / الاثنين
        return intl.DateFormat.E(locale).format(bucketStart);
      case TrendRange.weekly:
        // Week-of start date, e.g. 7/6
        return intl.DateFormat.Md(locale).format(bucketStart);
      case TrendRange.monthly:
        return 'months_abbr.${bucketStart.month}'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    final header = Row(
      children: [
        Expanded(
          child: Text(
            'healing_trend_graph'.tr(),
            style: t.textTheme.titleMedium,
          ),
        ),
      ],
    );

    final selector = _RangeSelector(value: range, onChanged: onRangeChanged);

    // --- Empty state: keep the selector so the range can still be changed ---
    if (series.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            SizedBox(height: 8.h),
            selector,
            SizedBox(height: 10.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
                constraints: BoxConstraints(minHeight: 220.h),
                width: double.infinity,
                color: t.colorScheme.surfaceVariant.withOpacity(.25),
                padding: EdgeInsets.all(16.w),
                child: Center(
                  child: Text(
                    'no_trend_data'.tr(),
                    textAlign: TextAlign.center,
                    style: t.textTheme.bodyMedium
                        ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final values = series.values;
    final n = values.length;

    // The time axis runs oldest → newest (left → right) in both locales, which
    // is what the app has always rendered: the previous `isRtl` branch compared
    // Flutter's `TextDirection` against intl's `TextDirection.RTL` (which
    // easy_localization re-exports), so it was never true. Mirroring the axis
    // only in Arabic would also fight the left-hand +% scale.
    final xLabels = List<String>.generate(
        n, (i) => _label(context, series.bucketStarts[i]));
    final spots =
        List<FlSpot>.generate(n, (i) => FlSpot(i.toDouble(), values[i]));

    // --- Axis ranges with padding ---
    final yMin = values.reduce((a, b) => a < b ? a : b).floorToDouble();
    final yMax = values.reduce((a, b) => a > b ? a : b).ceilToDouble();
    final pad = ((yMax - yMin).abs() * 0.2).clamp(1.0, 6.0);
    final minY = yMin - pad;
    final maxY = yMax + pad;

    double niceInterval(double r) {
      if (r <= 10) return 2;
      if (r <= 16) return 4;
      if (r <= 30) return 5;
      if (r <= 60) return 10;
      return 25;
    }

    final interval = niceInterval(maxY - minY);

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          SizedBox(height: 8.h),
          selector,
          SizedBox(height: 10.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              height: 220.h,
              color: t.colorScheme.surfaceVariant.withOpacity(.25),
              padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 12.h),
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (n - 1).toDouble(),
                  minY: minY,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (y) => FlLine(
                      color: t.dividerColor.withOpacity(.3),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36.w,
                        interval: interval,
                        getTitlesWidget: (value, meta) => Text(
                          (value % interval == 0)
                              ? (value >= 0
                                  ? '+${value.toStringAsFixed(0)}'
                                  : value.toStringAsFixed(0))
                              : '',
                          style: TextStyle(
                              fontSize: 12.sp,
                              color: t.colorScheme.onSurface.withOpacity(.6)),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        // Daily/weekly labels are wider than month abbreviations.
                        reservedSize: 28.h,
                        interval: 1,
                        getTitlesWidget: (v, meta) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= xLabels.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: EdgeInsets.only(top: 6.h),
                            child: Text(
                              xLabels[idx],
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                  fontSize: 10.sp,
                                  color:
                                      t.colorScheme.onSurface.withOpacity(.7)),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) => touchedSpots.map((it) {
                        final val = it.y.toStringAsFixed(0);
                        return LineTooltipItem(
                          it.y >= 0 ? '+$val' : val,
                          TextStyle(
                            color: t.colorScheme.onSurface,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 3,
                      color: t.colorScheme.primary,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: t.colorScheme.primary.withOpacity(.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Daily / Weekly / Monthly granularity picker.
///
/// `ChoiceChip` already exposes a `selected` semantics flag to screen readers.
/// `materialTapTargetSize: padded` keeps each chip a >=48dp touch target even
/// though the chip itself draws smaller.
class _RangeSelector extends StatelessWidget {
  final TrendRange value;
  final ValueChanged<TrendRange> onChanged;
  const _RangeSelector({required this.value, required this.onChanged});

  static const _labels = {
    TrendRange.daily: 'daily',
    TrendRange.weekly: 'weekly',
    TrendRange.monthly: 'monthly',
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Wrap(
      spacing: 8.w,
      runSpacing: 4.h,
      children: TrendRange.values.map((r) {
        final selected = r == value;
        return ChoiceChip(
          label: Text(_labels[r]!.tr(), style: t.textTheme.labelMedium),
          selected: selected,
          onSelected: (_) => onChanged(r),
          materialTapTargetSize: MaterialTapTargetSize.padded,
          showCheckmark: false,
        );
      }).toList(),
    );
  }
}
