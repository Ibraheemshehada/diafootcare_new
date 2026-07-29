import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../viewmodel/settings_viewmodel.dart';

class TermsScreen extends StatelessWidget {
  final bool
  blocking; // Determines if the user can navigate back or must accept the terms

  /// Review-only: the user opened this from Settings to re-read the terms. The
  /// acceptance is shown but cannot be toggled — they already agreed, and
  /// un-accepting here would leave the app in a contradictory state.
  final bool readOnly;

  const TermsScreen({super.key, this.blocking = false, this.readOnly = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final settings = context.watch<SettingsViewModel>();

    Widget item(int i, String titleKey, String bodyKey) => Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$i. ${titleKey.tr()}',
            style: t.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6.h),
          Text(bodyKey.tr(), style: t.textTheme.bodyMedium),
        ],
      ),
    );

    return WillPopScope(
      onWillPop: () async => !blocking, // Prevent back if required
      child: Scaffold(
        appBar: AppBar(title: Text('terms_title'.tr())),
        body: ListView(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
          children: [
            Text(
              'terms_intro'.tr(),
              style: t.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 16.h),

            item(1, 'terms_1_t', 'terms_1_b'),
            item(2, 'terms_2_t', 'terms_2_b'),
            item(3, 'terms_3_t', 'terms_3_b'),
            item(4, 'terms_4_t', 'terms_4_b'),
            item(5, 'terms_5_t', 'terms_5_b'),
            item(6, 'terms_6_t', 'terms_6_b'),

            SizedBox(height: 8.h),
            CheckboxListTile(
              value: settings.acceptedTerms,
              // Disabled in review mode: the user can see they accepted but
              // cannot change the answer from here.
              onChanged:
                  readOnly ? null : (v) => settings.setAcceptedTerms(v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              checkboxShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              activeColor: t.colorScheme.primary,
              title: Text(
                'i_agree'.tr(),
                style: t.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            SizedBox(height: 6.h),
            Text(
              'terms_footer'.tr(),
              style: t.textTheme.bodySmall?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(
              height: blocking ? 72.h : 0,
            ), // Leave room for bottom button
          ],
        ),
        bottomNavigationBar:
            blocking
                ? SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                    child: ConstrainedBox(
                      // minHeight (not an exact height): keeps the >=48dp touch
                      // target while letting the button grow when the user
                      // enlarges the system font. An exact height clipped labels.
                      constraints: BoxConstraints(minHeight: 48.h),
                      child: FilledButton(
                        onPressed:
                            settings.acceptedTerms
                                ? () => Navigator.pop(context, true)
                                : null,
                        child: Text('continue'.tr()),
                      ),
                    ),
                  ),
                )
                : null,
      ),
    );
  }
}
