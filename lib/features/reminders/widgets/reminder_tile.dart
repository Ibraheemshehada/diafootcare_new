// import 'package:easy_localization/easy_localization.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:intl/intl.dart' as intl;
//
// import '../../../data/models/reminder.dart';
//
// class ReminderTile extends StatelessWidget {
//   final Reminder r;
//   final VoidCallback onDelete;
//   final ValueChanged<bool> onToggle;
//
//   const ReminderTile({super.key, required this.r, required this.onDelete, required this.onToggle});
//
//   String _weekdayShort(BuildContext context, int weekday) {
//     // weekday: 1..7 (Mon..Sun)
//     final now = DateTime.now();
//     final delta = weekday - now.weekday;
//     final d = now.add(Duration(days: delta));
//     final locale = context.locale.toLanguageTag();
//     return intl.DateFormat('EEE', locale).format(d);
//   }
//
//   String _frequencyLabel(BuildContext context) {
//     if (r.repeatsDaily()) return 'daily'.tr();
//
//     // Natural order 1..7 (Mon..Sun)
//     const order = <int>[
//       DateTime.monday,
//       DateTime.tuesday,
//       DateTime.wednesday,
//       DateTime.thursday,
//       DateTime.friday,
//       DateTime.saturday,
//       DateTime.sunday,
//     ];
//
//     final picked = order.where((d) => r.weekdays.contains(d));
//     return picked.map((w) => _weekdayShort(context, w)).join(', ');
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     final t = Theme.of(context);
//     final timeText = r.time.format(context);
//
//     return Dismissible(
//       key: ValueKey(r.id),
//       direction: DismissDirection.endToStart,
//       background: Container(
//         alignment: Alignment.centerRight,
//         padding: EdgeInsets.symmetric(horizontal: 20.w),
//         color: Colors.red,
//         child: const Icon(Icons.delete, color: Colors.white),
//       ),
//       confirmDismiss: (_) async {
//         onDelete();
//         return true;
//       },
//       child: Container(
//         margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
//         padding: EdgeInsets.all(12.w),
//         decoration: BoxDecoration(
//           color: t.cardColor,
//           borderRadius: BorderRadius.circular(16.r),
//           border: Border.all(color: t.colorScheme.outlineVariant.withOpacity(.3)),
//           boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12, offset: Offset(0, 6))],
//         ),
//         child: Row(
//           children: [
//             Container(
//               width: 36.w,
//               height: 36.w,
//               decoration: BoxDecoration(
//                 color: t.colorScheme.secondaryContainer,
//                 borderRadius: BorderRadius.circular(10.r),
//               ),
//               child: Icon(Icons.info_outline_rounded, color: t.colorScheme.onSecondaryContainer, size: 20.sp),
//             ),
//             SizedBox(width: 10.w),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // "8:00 am"
//                   Text(timeText, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
//                   SizedBox(height: 4.h),
//                   // "Glucophage 500mg, 8:00 AM — Mon, Wed, Fri" OR "Wound Care, Daily"
//                   Text('${r.title}, $timeText — ${_frequencyLabel(context)}',
//                       style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
//                 ],
//               ),
//             ),
//             Switch(value: r.enabled, onChanged: onToggle),
//           ],
//         ),
//       ),
//     );
//   }
// }
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;

import '../../../data/models/reminder.dart';

class ReminderTile extends StatelessWidget {
  final Reminder r;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const ReminderTile({super.key, required this.r, required this.onDelete, required this.onToggle});

  String _weekdayShort(BuildContext context, int weekday) {
    final now = DateTime.now();
    final delta = weekday - now.weekday;
    final d = now.add(Duration(days: delta));
    final locale = context.locale.toLanguageTag();
    return intl.DateFormat('EEE', locale).format(d);
  }

  String _frequencyLabel(BuildContext context) {
    if (r.isOneOff()) {
      final locale = context.locale.toLanguageTag();
      final d = r.oneOffDate!;
      final dateTxt = intl.DateFormat.yMMMMd(locale).format(d);
      return tr('once_on', namedArgs: {'date': dateTxt}); // e.g., "Once — July 26, 2025"
    }
    if (r.repeatsDaily()) return 'daily'.tr();

    const order = <int>[
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ];
    final picked = order.where((d) => r.weekdays.contains(d));
    return picked.map((w) => _weekdayShort(context, w)).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final timeText = r.time.format(context);

    return Dismissible(
      key: ValueKey(r.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return true;
      },
      child: Container(
        margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: t.cardColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: t.colorScheme.outlineVariant.withOpacity(.3)),
          boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12, offset: Offset(0, 6))],
        ),
        child: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: t.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(Icons.info_outline_rounded, color: t.colorScheme.onSecondaryContainer, size: 20.sp),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(timeText, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  SizedBox(height: 4.h),
                  Text('${r.title}, $timeText — ${_frequencyLabel(context)}',
                      style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Switch(value: r.enabled, onChanged: onToggle),
          ],
        ),
      ),
    );
  }
}
