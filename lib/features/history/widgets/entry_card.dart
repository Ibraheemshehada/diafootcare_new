import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../data/models/wound_entry.dart';

class HistoryEntryCard extends StatelessWidget {
  final WoundEntry entry;
  final VoidCallback onView;
  const HistoryEntryCard({super.key, required this.entry, required this.onView});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      child: Container(
        decoration: BoxDecoration(
          color: t.cardColor,
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black12, offset: Offset(0,6))],
          border: Border.all(color: t.colorScheme.outlineVariant.withOpacity(.3)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.only(topLeft: Radius.circular(14.r), bottomLeft: Radius.circular(14.r)),
              child: Image.asset(entry.imagePath, width: 120.w, height: 120.w, fit: BoxFit.cover),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row(t, "size".tr(), "${entry.lengthCm.toStringAsFixed(1)} x ${entry.widthCm.toStringAsFixed(1)} cm"),
                    SizedBox(height: 4.h),
                    _row(t, "inflammation".tr(), entry.inflammation),
                    SizedBox(height: 4.h),
                    _row(t,  "progress".tr(), "+${entry.progressPct.toStringAsFixed(0)}%"),
                    SizedBox(height: 10.h),
                    SizedBox(
                      height: 36.h,
                      child: FilledButton(
                        onPressed: onView,
                        child: Text("view_details".tr(), style: TextStyle(fontSize: 13.sp)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(ThemeData t, String k, String v) => Row(
    children: [
      Text("$k : ", style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      Flexible(child: Text(v, style: t.textTheme.bodyMedium)),
    ],
  );
}
