import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../data/models/education_article.dart';

class EducationArticleScreen extends StatelessWidget {
  final EducationArticle article;
  const EducationArticleScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final primary = t.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(article.titleKey.tr(),
            style: TextStyle(fontSize: 17.sp),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
        children: [
          Row(
            children: [
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(article.icon, color: primary, size: 26.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(article.titleKey.tr(),
                    style: TextStyle(
                        fontSize: 19.sp, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Text(article.introKey.tr(),
              style: TextStyle(
                  fontSize: 14.sp,
                  height: 1.5,
                  color: t.colorScheme.onSurface)),
          SizedBox(height: 18.h),
          ...article.bulletKeys.map((k) => Padding(
                padding: EdgeInsets.only(bottom: 14.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 20.sp, color: primary),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(k.tr(),
                          style: TextStyle(
                              fontSize: 14.sp,
                              height: 1.45,
                              color: t.colorScheme.onSurface)),
                    ),
                  ],
                ),
              )),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18.sp, color: primary),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text('edu_disclaimer'.tr(),
                      style: TextStyle(fontSize: 11.sp, color: t.hintColor)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
