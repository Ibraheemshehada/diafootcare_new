// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:intl/intl.dart' as intl;
//
// class DayChip extends StatelessWidget {
//   final DateTime date;
//   final bool selected;
//   final VoidCallback onTap;
//
//   const DayChip({super.key, required this.date, required this.selected, required this.onTap});
//
//   @override
//   Widget build(BuildContext context) {
//     final t = Theme.of(context);
//     final locale = Localizations.localeOf(context).toLanguageTag();
//     final dayNum = date.day.toString();
//     final dayAbbr = intl.DateFormat('EEE', locale).format(date); // localized short day
//
//     final border = selected ? Border.all(color: t.colorScheme.primary, width: 2) : null;
//     final bg = selected ? t.colorScheme.primary.withOpacity(.08) : t.colorScheme.surface;
//
//     return InkWell(
//       borderRadius: BorderRadius.circular(12.r),
//       onTap: onTap,
//       child: Container(
//         width: 50.w,
//         padding: EdgeInsets.symmetric(vertical: 10.h),
//         decoration: BoxDecoration(
//           color: bg,
//           border: border,
//           borderRadius: BorderRadius.circular(12.r),
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(dayNum, style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
//             SizedBox(height: 4.h),
//             Text(dayAbbr.toUpperCase(), style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
//           ],
//         ),
//       ),
//     );
//   }
// }
// lib/features/reminders/widgets/day_chip.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class DayChip extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  const DayChip({super.key, required this.date, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final dayNum = date.day.toString();
    // ultra-short weekday from translations to avoid overflow
    final dayAbbr = 'week_abbr.${date.weekday}'.tr(); // 1..7

    final border = selected ? Border.all(color: t.colorScheme.primary, width: 2) : null;
    final bg = selected ? t.colorScheme.primary.withOpacity(.08) : t.colorScheme.surface;

    return InkWell(
      borderRadius: BorderRadius.circular(12.r),
      onTap: onTap,
      child: Container(
        // ensure enough vertical space on all devices/text scales
        constraints: BoxConstraints(minWidth: 56.w, minHeight: 64.h),
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 6.w),
        decoration: BoxDecoration(color: bg, border: border, borderRadius: BorderRadius.circular(12.r)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              dayNum,
              maxLines: 1,
              overflow: TextOverflow.fade,
              style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 16.sp),
            ),
            SizedBox(height: 2.h),
            Text(
              dayAbbr, // already short (e.g., WED / أربع)
              maxLines: 1,
              overflow: TextOverflow.fade,
              style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant, fontSize: 10.sp),
            ),
          ],
        ),
      ),
    );
  }
}
