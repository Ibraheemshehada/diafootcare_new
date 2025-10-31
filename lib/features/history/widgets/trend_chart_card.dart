import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class TrendChartCard extends StatelessWidget {
  /// Expected to be percent deltas (e.g., 12..18). If empty, we’ll use dummy data.
  final List<double> monthlyTrend;
  const TrendChartCard({super.key, required this.monthlyTrend});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isRtl = Directionality.of(context) == TextDirection.RTL;

    // --- 1) Data (fallback to dummy if empty) ---
    final mainSeries = (monthlyTrend.isEmpty)
        ? <double>[12, 14, 13, 16, 18, 15, 15]  // dummy like your mock
        : monthlyTrend;

    // a faint comparison/baseline (dummy)
    final baseline = <double>[12, 13, 12.5, 12.8, 13.2, 13.8, 14];

    final n = mainSeries.length;

    // --- 2) Localized month labels: last n months ending this month ---
    final now = DateTime.now();
    final months = List<String>.generate(n, (i) {
      // build from oldest → newest
      final m = ((now.month - (n - 1 - i) - 1) % 12) + 1; // wrap 1..12
      return 'months_abbr.$m'.tr();
    });

    // If RTL, reverse labels so graph flows right→left
    final xLabels = isRtl ? months.reversed.toList(growable: false) : months;

    // --- 3) Convert to FlSpots (flip X order for RTL) ---
    List<FlSpot> _toSpots(List<double> vals) {
      if (isRtl) {
        return List<FlSpot>.generate(n, (i) => FlSpot(i.toDouble(), vals.reversed.elementAt(i)));
      } else {
        return List<FlSpot>.generate(n, (i) => FlSpot(i.toDouble(), vals[i]));
      }
    }

    final mainSpots = _toSpots(mainSeries);
    final baseSpots = _toSpots(baseline);

    // --- 4) Axis ranges with padding ---
    final allY = [...mainSeries, ...baseline];
    final yMin = (allY.reduce((a, b) => a < b ? a : b)).floorToDouble();
    final yMax = (allY.reduce((a, b) => a > b ? a : b)).ceilToDouble();
    final pad = ((yMax - yMin).abs() * 0.2).clamp(1.0, 6.0);
    final minY = (yMin - pad);
    final maxY = (yMax + pad);

    // Choose a nice tick interval
    double niceInterval(double range) {
      if (range <= 6) return 2;
      if (range <= 10) return 2;
      if (range <= 16) return 4;
      return 5;
    }
    final interval = niceInterval(maxY - minY);

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text("healing_trend_graph".tr(), style: t.textTheme.titleMedium),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: t.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Text("monthly".tr(), style: t.textTheme.labelMedium),
              ),
            ],
          ),
          SizedBox(height: 10.h),

          // Chart
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
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36.w,
                        interval: interval,
                        getTitlesWidget: (value, meta) => Text(
                          // Show as +12 etc.
                          (value % interval == 0)
                              ? (value >= 0 ? '+${value.toStringAsFixed(0)}' : value.toStringAsFixed(0))
                              : '',
                          style: TextStyle(fontSize: 10.sp, color: t.colorScheme.onSurface.withOpacity(.6)),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (v, meta) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= xLabels.length) return const SizedBox.shrink();
                          return Padding(
                            padding: EdgeInsets.only(top: 6.h),
                            child: Text(
                              xLabels[idx],
                              style: TextStyle(fontSize: 10.sp, color: t.colorScheme.onSurface.withOpacity(.7)),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),

                  // Tooltips
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) => touchedSpots.map((it) {
                        final val = it.y.toStringAsFixed(0);
                        return LineTooltipItem(
                          // e.g., +18
                          (it.y >= 0 ? '+$val' : val),
                          TextStyle(
                            color: t.colorScheme.onSurface,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Series
                  lineBarsData: [
                    // Main (blue)
                    LineChartBarData(
                      spots: mainSpots,
                      isCurved: true,
                      barWidth: 3,
                      color: t.colorScheme.primary,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: t.colorScheme.primary.withOpacity(.12),
                      ),
                    ),
                    // Baseline (gray)
                    LineChartBarData(
                      spots: baseSpots,
                      isCurved: true,
                      barWidth: 3,
                      color: t.colorScheme.onSurfaceVariant,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: t.colorScheme.onSurfaceVariant.withOpacity(.08),
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
