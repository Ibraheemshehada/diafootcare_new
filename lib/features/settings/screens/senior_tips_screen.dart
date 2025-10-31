import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SeniorTipsScreen extends StatelessWidget {
  const SeniorTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    Widget tip(int i, String titleKey, String bodyKey) {
      return Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: t.cardColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: t.colorScheme.outlineVariant.withOpacity(.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$i. ${titleKey.tr()}',
              style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6.h),
            Text(bodyKey.tr(), style: t.textTheme.bodyMedium),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('senior_tips_title'.tr())),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
        children: [
          tip(1, 'senior_tip_1_t', 'senior_tip_1_b'),
          tip(2, 'senior_tip_2_t', 'senior_tip_2_b'),
          tip(3, 'senior_tip_3_t', 'senior_tip_3_b'),
          tip(4, 'senior_tip_4_t', 'senior_tip_4_b'),
          tip(5, 'senior_tip_5_t', 'senior_tip_5_b'),
          tip(6, 'senior_tip_6_t', 'senior_tip_6_b'),
          tip(7, 'senior_tip_7_t', 'senior_tip_7_b'),
        ],
      ),
    );
  }
}
