// import 'package:fl_chart/fl_chart.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:flutter_svg/flutter_svg.dart';
//
// import '../../../data/models/wound_entry.dart';
// // If you already created this for AI results, you can pass real values.
// // For now we keep a light struct here to render the UI.
// class HealingResult {
//   final double length, width, depth;
//   final String tissueType, pusLevel, inflammation;
//   final double weeklyProgress;
//   final String graphImagePath; // asset (placeholder)
//   const HealingResult({
//     required this.length,
//     required this.width,
//     required this.depth,
//     required this.tissueType,
//     required this.pusLevel,
//     required this.inflammation,
//     required this.weeklyProgress,
//     this.graphImagePath = 'assets/images/progress_graph.png',
//   });
// }
//
// class HealingProgressScreen extends StatelessWidget {
//   final WoundEntry entry;
//   final HealingResult result;
//
//   const HealingProgressScreen({
//     super.key,
//     required this.entry,
//     required this.result,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final t = Theme.of(context);
//     final primary = t.colorScheme.primary;
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Healing Progress', style: TextStyle(fontSize: 18.sp)),
//       ),
//       body: SafeArea(
//         child: ListView(
//           padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
//           children: [
//             // Top photo header
//             ClipRRect(
//               borderRadius: BorderRadius.circular(14.r),
//               child: AspectRatio(
//                 aspectRatio: 16 / 9,
//                 child: Image.asset(entry.imagePath, fit: BoxFit.cover),
//               ),
//             ),
//             SizedBox(height: 20.h),
//
//             _SectionTitle('Measurements'),
//             SizedBox(height: 12.h),
//
//             _StatCard(icon: Icons.straighten, value: result.length, label: 'Length', color: primary, quarterTurns: 1),
//             SizedBox(height: 10.h),
//             _StatCard(icon: Icons.straighten, value: result.width,  label: 'Width',  color: primary),
//             SizedBox(height: 10.h),
//             _StatCard(svgAsset: 'assets/svg/arrow_down.svg', value: result.depth,  label: 'Depth',  color: primary),
//
//             SizedBox(height: 20.h),
//             _SectionTitle('Wound Details'),
//             SizedBox(height: 12.h),
//
//             _DetailCard(svgAsset: 'assets/svg/micro.svg', title: result.tissueType, subtitle: 'Tissue Type', color: primary),
//             SizedBox(height: 10.h),
//             _DetailCard(icon: Icons.opacity_outlined, title: result.pusLevel, subtitle: 'Pus Level', color: primary),
//             SizedBox(height: 10.h),
//             _DetailCard(icon: Icons.local_fire_department_outlined, title: result.inflammation, subtitle: 'Inflammation', color: primary),
//
//             SizedBox(height: 20.h),
//             _SectionTitle('Progress Summary'),
//             SizedBox(height: 12.h),
//
//             _DetailCard(
//               icon: Icons.trending_up_rounded,
//               title: '+${result.weeklyProgress.toStringAsFixed(0)}% since last week',
//               subtitle: 'Healing Progress',
//               color: primary,
//             ),
//
//             SizedBox(height: 20.h),
//             _SectionTitle('Progress Graph'),
//             SizedBox(height: 12.h),
//             // ClipRRect(
//             //   borderRadius: BorderRadius.circular(12.r),
//             //   child: Image.asset(result.graphImagePath, fit: BoxFit.contain),
//             // ),
//             ClipRRect(
//               borderRadius: BorderRadius.circular(12.r),
//               child: _ProgressLineChart(),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// /* ---------- shared section title ---------- */
// class _SectionTitle extends StatelessWidget {
//   final String text;
//   const _SectionTitle(this.text);
//   @override
//   Widget build(BuildContext context) => Text(
//     text,
//     style: Theme.of(context).textTheme.titleLarge?.copyWith(
//       fontSize: 20.sp,
//       fontWeight: FontWeight.w700,
//     ),
//   );
// }
//
// /* ---------- StatCard supports IconData or SVG + rotation ---------- */
// class _StatCard extends StatelessWidget {
//   final IconData? icon;
//   final String? svgAsset;
//   final double value;
//   final String label;
//   final Color color;
//   final int quarterTurns;
//   final String unit;
//
//   const _StatCard({
//     this.icon,
//     this.svgAsset,
//     required this.value,
//     required this.label,
//     required this.color,
//     this.quarterTurns = 0,
//     this.unit = 'cm',
//     super.key,
//   }) : assert(icon != null || svgAsset != null, 'Provide either icon or svgAsset');
//
//   @override
//   Widget build(BuildContext context) {
//     final t = Theme.of(context);
//     Widget leading = svgAsset != null
//         ? SvgPicture.asset(svgAsset!, width: 22.w, height: 22.w, colorFilter: ColorFilter.mode(color, BlendMode.srcIn))
//         : Icon(icon, size: 22.sp, color: color);
//     leading = RotatedBox(quarterTurns: quarterTurns, child: leading);
//
//     return Container(
//       padding: EdgeInsets.all(14.w),
//       decoration: BoxDecoration(
//         color: t.cardColor,
//         borderRadius: BorderRadius.circular(12.r),
//         border: Border.all(color: t.colorScheme.outlineVariant.withOpacity(.35)),
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 40.w,
//             height: 40.w,
//             decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(10.r)),
//             child: Center(child: leading),
//           ),
//           SizedBox(width: 12.w),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text('${value.toStringAsFixed(1)} $unit',
//                   style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 16.sp)),
//               SizedBox(height: 2.h),
//               Text(label, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant, fontSize: 12.sp)),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// /* ---------- DetailCard supports IconData or SVG ---------- */
// class _DetailCard extends StatelessWidget {
//   final IconData? icon;
//   final String? svgAsset;
//   final String title;
//   final String subtitle;
//   final Color color;
//
//   const _DetailCard({
//     this.icon,
//     this.svgAsset,
//     required this.title,
//     required this.subtitle,
//     required this.color,
//     super.key,
//   }) : assert(icon != null || svgAsset != null, 'You must provide either icon or svgAsset');
//
//   @override
//   Widget build(BuildContext context) {
//     final t = Theme.of(context);
//     return Container(
//       padding: EdgeInsets.all(14.w),
//       decoration: BoxDecoration(
//         color: t.cardColor,
//         borderRadius: BorderRadius.circular(12.r),
//         border: Border.all(color: t.colorScheme.outlineVariant.withOpacity(.35)),
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 40.w,
//             height: 40.w,
//             decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(10.r)),
//             child: Center(
//               child: svgAsset != null
//                   ? SvgPicture.asset(svgAsset!, width: 22.w, height: 22.w, colorFilter: ColorFilter.mode(color, BlendMode.srcIn))
//                   : Icon(icon, size: 22.sp, color: color),
//             ),
//           ),
//           SizedBox(width: 12.w),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(title, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 16.sp)),
//               SizedBox(height: 2.h),
//               Text(subtitle, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant, fontSize: 12.sp)),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
// class _ProgressLineChart extends StatelessWidget {
//   const _ProgressLineChart({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final t = Theme.of(context);
//     final primary = t.colorScheme.primary;
//     final neutral = t.colorScheme.onSurfaceVariant;
//
//     // Dummy monthly data (0..6 => Feb..Aug)
//     final treatment = <FlSpot>[
//       const FlSpot(0, 1100),
//       const FlSpot(1, 860),
//       const FlSpot(2, 540),
//       const FlSpot(3, 280),
//       const FlSpot(4, 120),
//       const FlSpot(5, 40),
//       const FlSpot(6, 15),
//     ];
//     final control = <FlSpot>[
//       const FlSpot(0, 780),
//       const FlSpot(1, 720),
//       const FlSpot(2, 650),
//       const FlSpot(3, 520),
//       const FlSpot(4, 410),
//       const FlSpot(5, 360),
//       const FlSpot(6, 330),
//     ];
//
//     return Container(
//       height: 220.h,
//       padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 12.h),
//       color: t.colorScheme.surfaceVariant.withOpacity(.25),
//       child: LineChart(
//         LineChartData(
//           minX: 0, maxX: 6, minY: 0, maxY: 1200,
//           gridData: FlGridData(
//             show: true,
//             drawVerticalLine: false,
//             horizontalInterval: 200,
//             getDrawingHorizontalLine: (y) => FlLine(
//               color: t.dividerColor.withOpacity(.3), strokeWidth: 1,
//             ),
//           ),
//           titlesData: FlTitlesData(
//             topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//             rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//             leftTitles: AxisTitles(
//               sideTitles: SideTitles(
//                 showTitles: true,
//                 reservedSize: 36.w,
//                 interval: 400,
//                 getTitlesWidget: (value, meta) => Text(
//                   value.toInt().toString(),
//                   style: TextStyle(fontSize: 10.sp, color: t.colorScheme.onSurface.withOpacity(.6)),
//                 ),
//               ),
//             ),
//             bottomTitles: AxisTitles(
//               sideTitles: SideTitles(
//                 showTitles: true,
//                 interval: 1,
//                 getTitlesWidget: (value, meta) {
//                   const labels = ['Feb','Mar','Apr','May','Jun','Jul','Aug'];
//                   final idx = value.toInt().clamp(0, labels.length - 1);
//                   return Padding(
//                     padding: EdgeInsets.only(top: 6.h),
//                     child: Text(labels[idx], style: TextStyle(fontSize: 10.sp, color: t.colorScheme.onSurface.withOpacity(.7))),
//                   );
//                 },
//               ),
//             ),
//           ),
//           lineTouchData: LineTouchData(
//             handleBuiltInTouches: true,
//             touchTooltipData: LineTouchTooltipData(
//               // tooltipBgColor: t.colorScheme.surface.withOpacity(.95),
//               getTooltipItems: (items) => items.map((it) {
//                 final series = it.barIndex == 0 ? 'Treatment' : 'Control';
//                 return LineTooltipItem(
//                   '$series\n${it.y.toStringAsFixed(0)} mm²',
//                   TextStyle(color: t.colorScheme.onSurface, fontSize: 11.sp, fontWeight: FontWeight.w600),
//                 );
//               }).toList(),
//             ),
//           ),
//           borderData: FlBorderData(show: false),
//           lineBarsData: [
//             LineChartBarData(
//               spots: treatment,
//               isCurved: true,
//               barWidth: 3,
//               color: primary,
//               dotData: FlDotData(show: false),
//               belowBarData: BarAreaData(
//                 show: true,
//                 color: primary.withOpacity(.12),
//               ),
//             ),
//             LineChartBarData(
//               spots: control,
//               isCurved: true,
//               barWidth: 3,
//               color: neutral,
//               dotData: FlDotData(show: false),
//               belowBarData: BarAreaData(
//                 show: true,
//                 color: neutral.withOpacity(.08),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../data/models/wound_entry.dart';
import '../../../data/repositories/wounds_repository.dart';

class HealingResult {
  final double length, width, depth;
  final String tissueType, pusLevel, inflammation;
  final double weeklyProgress;
  final String graphImagePath;
  const HealingResult({
    required this.length,
    required this.width,
    required this.depth,
    required this.tissueType,
    required this.pusLevel,
    required this.inflammation,
    required this.weeklyProgress,
    this.graphImagePath = 'assets/images/progress_graph.png',
  });
}

class HealingProgressScreen extends StatefulWidget {
  final WoundEntry entry;
  final HealingResult result;

  const HealingProgressScreen({
    super.key,
    required this.entry,
    required this.result,
  });

  @override
  State<HealingProgressScreen> createState() => _HealingProgressScreenState();
}

class _HealingProgressScreenState extends State<HealingProgressScreen> {
  List<WoundEntry>? _allEntries;
  bool _loadingData = true;

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
          _allEntries = entries;
          _loadingData = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading history data: $e');
      if (mounted) {
        setState(() {
          _loadingData = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final primary = t.colorScheme.primary;
    final entry = widget.entry;
    final result = widget.result;

    return Scaffold(
      appBar: AppBar(
        title: Text('healing_progress'.tr(), style: TextStyle(fontSize: 18.sp)),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14.r),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child:
                    entry.imagePath.startsWith('assets/')
                        ? Image.asset(entry.imagePath, fit: BoxFit.cover)
                        : (File(entry.imagePath).existsSync()
                            ? Image.file(
                              File(entry.imagePath),
                              fit: BoxFit.cover,
                            )
                            : Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: Icon(Icons.image_not_supported),
                              ),
                            )),
              ),
            ),
            SizedBox(height: 20.h),

            _SectionTitle('measurements'.tr()),
            SizedBox(height: 12.h),

            _StatCard(
              icon: Icons.straighten,
              value: result.length,
              label: 'length'.tr(),
              unit: 'unit_cm'.tr(),
              color: primary,
              quarterTurns: 1,
            ),
            SizedBox(height: 10.h),
            _StatCard(
              icon: Icons.straighten,
              value: result.width,
              label: 'width'.tr(),
              unit: 'unit_cm'.tr(),
              color: primary,
            ),
            SizedBox(height: 10.h),
            _StatCard(
              svgAsset: 'assets/svg/arrow_down.svg',
              value: result.depth,
              label: 'depth'.tr(),
              unit: 'unit_cm'.tr(),
              color: primary,
            ),

            SizedBox(height: 20.h),
            _SectionTitle('wound_details'.tr()),
            SizedBox(height: 12.h),

            _DetailCard(
              svgAsset: 'assets/svg/micro.svg',
              title: result.tissueType,
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
              title: 'progress_since_last_week'.tr(
                namedArgs: {
                  'percent': result.weeklyProgress.toStringAsFixed(0),
                },
              ),
              subtitle: 'healing_progress_title'.tr(),
              color: primary,
            ),

            SizedBox(height: 20.h),
            _SectionTitle('progress_graph'.tr()),
            SizedBox(height: 12.h),

            ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: _ProgressLineChart(
                allEntries: _allEntries ?? [],
                currentEntry: entry,
                isLoading: _loadingData,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
                '${value.toStringAsFixed(1)} $unit',
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
                title,
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

class _ProgressLineChart extends StatelessWidget {
  final List<WoundEntry> allEntries;
  final WoundEntry currentEntry;
  final bool isLoading;

  const _ProgressLineChart({
    super.key,
    required this.allEntries,
    required this.currentEntry,
    required this.isLoading,
  });

  /// Calculate wound area in mm² (for chart display)
  double _calculateArea(WoundEntry entry) {
    // Convert cm to mm and calculate area
    return (entry.lengthCm * 10) * (entry.widthCm * 10);
  }

  List<FlSpot> _generateDataPoints() {
    if (isLoading || allEntries.isEmpty) {
      // Return empty or placeholder data
      return [];
    }

    // Get last 7 entries (or all if less than 7)
    final entries = allEntries.length > 7 
        ? allEntries.sublist(allEntries.length - 7)
        : allEntries;

    // Create data points with area in mm²
    return entries.asMap().entries.map((entry) {
      final index = entry.key;
      final wound = entry.value;
      final area = _calculateArea(wound);
      return FlSpot(index.toDouble(), area);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final primary = t.colorScheme.primary;

    // Generate data points from actual wound entries
    final dataPoints = _generateDataPoints();
    
    // Calculate min/max for chart scaling
    double maxY = 1200.0; // Default max
    double minY = 0.0;
    
    if (dataPoints.isNotEmpty) {
      final areas = dataPoints.map((spot) => spot.y).toList();
      final maxArea = areas.reduce((a, b) => a > b ? a : b);
      final minArea = areas.reduce((a, b) => a < b ? a : b);
      
      // Set max to 120% of max area, rounded to nearest 100
      maxY = ((maxArea * 1.2) / 100).ceil() * 100.0;
      minY = (minArea * 0.8).clamp(0.0, double.infinity);
    }

    final maxX = dataPoints.isNotEmpty ? (dataPoints.length - 1).toDouble() : 6.0;

    if (isLoading) {
      return Container(
        height: 220.h,
        padding: EdgeInsets.all(12.w),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (dataPoints.isEmpty) {
      return Container(
        height: 220.h,
        padding: EdgeInsets.all(12.w),
        color: t.colorScheme.surfaceVariant.withOpacity(.25),
        child: Center(
          child: Text(
            'no_history_data'.tr(),
            style: t.textTheme.bodyMedium?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // final months = tr(List<String>.from(tr('months', args: [], namedArgs: {}, gender: null, ) as List).isEmpty
    //     ? 'months'
    //     : 'months') as List<dynamic>;
    // // Safer cast to List<String>
    // final monthLabels = months.map((e) => e.toString()).toList(growable: false);

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
            horizontalInterval: 200,
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
                interval: maxY / 5, // Show 5 intervals
                getTitlesWidget:
                    (value, meta) => Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: t.colorScheme.onSurface.withOpacity(.6),
                      ),
                    ),
              ),
            ),
            // bottomTitles: AxisTitles(
            //   sideTitles: SideTitles(
            //     showTitles: true,
            //     interval: 1,
            //     getTitlesWidget: (value, meta) {
            //       final idx = value.toInt().clamp(0, monthLabels.length - 1);
            //       return Padding(
            //         padding: EdgeInsets.only(top: 6.h),
            //         child: Text(
            //           monthLabels[idx],
            //           style: TextStyle(fontSize: 10.sp, color: t.colorScheme.onSurface.withOpacity(.7)),
            //         ),
            //       );
            //     },
            //   ),
            // ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: dataPoints.length <= 7, // Only show labels if we have 7 or fewer points
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt().clamp(0, dataPoints.length - 1);
                  if (idx < allEntries.length) {
                    final entry = allEntries[allEntries.length - dataPoints.length + idx];
                    final month = entry.date.month;
                    final monthName = 'months_abbr.$month'.tr();
                    return Padding(
                      padding: EdgeInsets.only(top: 6.h),
                      child: Text(
                        monthName,
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: t.colorScheme.onSurface.withOpacity(.7),
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
                        final series =
                            it.barIndex == 0
                                ? 'series_treatment'.tr()
                                : 'series_control'.tr();
                        return LineTooltipItem(
                          '$series\n' +
                              'area_mm2'.tr(
                                namedArgs: {'value': it.y.toStringAsFixed(0)},
                              ),
                          TextStyle(
                            color: t.colorScheme.onSurface,
                            fontSize: 11.sp,
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
                  // Highlight current entry
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
