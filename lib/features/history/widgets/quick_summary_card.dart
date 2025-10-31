// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
//
// class QuickSummaryCard extends StatelessWidget {
//   final int totalEntries;
//   final int improvementPct;
//   final String inflammationTrend;
//   const QuickSummaryCard({
//     super.key,
//     required this.totalEntries,
//     required this.improvementPct,
//     required this.inflammationTrend,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final t = Theme.of(context);
//     return Container(
//       margin: EdgeInsets.symmetric(horizontal: 16.w),
//       padding: EdgeInsets.all(16.w),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topLeft, end: Alignment.bottomRight,
//           colors: [t.colorScheme.primary.withOpacity(.95), t.colorScheme.primary],
//         ),
//         borderRadius: BorderRadius.circular(16.r),
//         boxShadow: const [BoxShadow(blurRadius: 16, color: Colors.black12, offset: Offset(0,8))],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text("Quick Summary", style: t.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
//           SizedBox(height: 10.h),
//           _row("Total Entries: $totalEntries"),
//           _row("Overall Improvement: +$improvementPct%"),
//           _row("Inflammation trend: $inflammationTrend"),
//         ],
//       ),
//     );
//   }
//
//   Widget _row(String text) => Padding(
//     padding: EdgeInsets.symmetric(vertical: 4.h),
//     child: Text(text, style: TextStyle(color: Colors.white, fontSize: 14.sp)),
//   );
// }
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

class QuickSummaryCard extends StatelessWidget {
  final int totalEntries;
  final int improvementPct;
  final String inflammationTrend;

  const QuickSummaryCard({
    super.key,
    required this.totalEntries,
    required this.improvementPct,
    required this.inflammationTrend,
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
                  // Top-right bg shape
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
                          Colors.white.withOpacity(0.06),
                          BlendMode.srcATop,
                        ),
                      ),
                    ),
                  ),

                  // Bottom-left bg shape
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
                          Colors.white.withOpacity(0.06),
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
                      children: [
                        Text(
                          "quick_summary".tr(),
                          style: t.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 10.h),
                        _row("total_entries".tr(namedArgs: {'count': totalEntries.toString()})),
                        _row("overall_improvement".tr(namedArgs: {'percent': improvementPct.toString()})),
                        _row("inflammation_trend".tr(namedArgs: {'trend': inflammationTrend})),
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

  Widget _row(String text) => Padding(
    padding: EdgeInsets.symmetric(vertical: 4.h),
    child: Text(
      text,
      style: TextStyle(color: Colors.white, fontSize: 14.sp),
    ),
  );
}
