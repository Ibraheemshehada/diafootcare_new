import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/education_article.dart';
import 'education_article_screen.dart';

class EducationScreen extends StatelessWidget {
  const EducationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('edu_title'.tr(), style: TextStyle(fontSize: 18.sp)),
        backgroundColor: t.scaffoldBackgroundColor,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
        children: [
          Text('edu_subtitle'.tr(),
              style: TextStyle(fontSize: 13.sp, color: t.hintColor)),
          SizedBox(height: 16.h),
          Text('edu_articles'.tr(),
              style: t.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          SizedBox(height: 8.h),
          ...educationArticles.map((a) => _ArticleCard(article: a)),
          SizedBox(height: 16.h),
          const _PharmacistTipsCard(),
          SizedBox(height: 16.h),
          const _AskPharmacistCard(),
        ],
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final EducationArticle article;
  const _ArticleCard({required this.article});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Study metric: help/tutorial usage.
            AnalyticsService.I.logHelp('education_article:${article.key}');
            Navigator.push(
              context,
              MaterialPageRoute(
                  settings: const RouteSettings(name: '/education/article'),
                  builder: (_) => EducationArticleScreen(article: article)),
            );
          },
          borderRadius: BorderRadius.circular(14.r),
          child: Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: t.cardColor,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: t.dividerColor.withValues(alpha: .3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42.w,
                  height: 42.w,
                  decoration: BoxDecoration(
                    color: t.colorScheme.primary.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(article.icon,
                      color: t.colorScheme.primary, size: 22.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(article.titleKey.tr(),
                          style: TextStyle(
                              fontSize: 15.sp, fontWeight: FontWeight.w700)),
                      SizedBox(height: 2.h),
                      Text(article.summaryKey.tr(),
                          style:
                              TextStyle(fontSize: 12.sp, color: t.hintColor)),
                    ],
                  ),
                ),
                SizedBox(width: 6.w),
                Icon(isRtl ? Icons.chevron_left : Icons.chevron_right,
                    color: t.hintColor, size: 22.sp),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PharmacistTipsCard extends StatelessWidget {
  const _PharmacistTipsCard();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final primary = t.colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: primary.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_pharmacy_outlined, color: primary, size: 22.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text('edu_pharmacist'.tr(),
                    style: TextStyle(
                        fontSize: 15.sp, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified,
                        size: 13.sp, color: AppColors.of(context).success),
                    SizedBox(width: 4.w),
                    Text('edu_verified'.tr(),
                        style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.of(context).success)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ...List.generate(educationPharmacistTipCount, (i) {
            return Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 6.h),
                    child: Container(
                      width: 6.w,
                      height: 6.w,
                      decoration:
                          BoxDecoration(color: primary, shape: BoxShape.circle),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text('edu_pharm_${i + 1}'.tr(),
                        style: TextStyle(
                            fontSize: 13.sp,
                            height: 1.4,
                            color: t.colorScheme.onSurface)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AskPharmacistCard extends StatelessWidget {
  const _AskPharmacistCard();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: t.dividerColor.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline,
                  color: t.colorScheme.primary, size: 22.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text('edu_ask_title'.tr(),
                    style: TextStyle(
                        fontSize: 15.sp, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text('edu_ask_intro'.tr(),
              style: TextStyle(fontSize: 12.sp, color: t.hintColor)),
          SizedBox(height: 12.h),
          ...List.generate(educationAskQuestionCount, (i) {
            return Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 15.sp, color: t.colorScheme.primary),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text('edu_ask_q${i + 1}'.tr(),
                        style: TextStyle(
                            fontSize: 13.sp,
                            height: 1.4,
                            color: t.colorScheme.onSurface)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
