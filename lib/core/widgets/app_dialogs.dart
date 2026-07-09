import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';
import '../services/analytics_service.dart';

enum AppMessageKind { success, error, warning, info }

/// App-wide message dialogs used instead of SnackBars for **save confirmations
/// and error messages**.
///
/// Accessibility notes:
/// * Dialogs are announced by TalkBack/VoiceOver when the route opens, unlike
///   SnackBars which are easy to miss and auto-dismiss before they're read.
/// * Body text is >= 14.sp and the action button is a full 48dp touch target.
/// * The icon is decorative (`excludeSemantics`) so the reader isn't cluttered.
Future<void> showAppMessage(
  BuildContext context, {
  required String message,
  String? title,
  AppMessageKind kind = AppMessageKind.info,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _AppMessageDialog(
      message: message,
      title: title,
      kind: kind,
    ),
  );
}

/// Success / "saved" confirmation.
Future<void> showAppSuccess(BuildContext context, String message) =>
    showAppMessage(context,
        message: message,
        title: 'dialog_saved_title'.tr(),
        kind: AppMessageKind.success);

/// User-facing error. [technicalDetail] is never shown to the user — it is
/// logged locally so the study/dev can diagnose without leaking a raw stack
/// trace or exception string into the UI.
///
/// Every error shown to the user is recorded as an `error` event, including
/// *user* errors such as failed validation — those are precisely what a
/// usability study's "error logs" are meant to capture.
Future<void> showAppError(
  BuildContext context,
  String message, {
  Object? technicalDetail,
}) {
  if (technicalDetail != null) {
    debugPrint('❌ $message | $technicalDetail');
    AnalyticsService.I.logError('$message | $technicalDetail');
  } else {
    AnalyticsService.I.logError(message);
  }
  return showAppMessage(context,
      message: message,
      title: 'dialog_error_title'.tr(),
      kind: AppMessageKind.error);
}

class _AppMessageDialog extends StatelessWidget {
  final String message;
  final String? title;
  final AppMessageKind kind;
  const _AppMessageDialog({
    required this.message,
    required this.title,
    required this.kind,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    late final Color color;
    late final IconData icon;
    switch (kind) {
      case AppMessageKind.success:
        color = AppColors.of(context).success;
        icon = Icons.check_circle_outline;
        break;
      case AppMessageKind.error:
        color = AppColors.of(context).danger;
        icon = Icons.error_outline;
        break;
      case AppMessageKind.warning:
        color = AppColors.of(context).warning;
        icon = Icons.warning_amber_rounded;
        break;
      case AppMessageKind.info:
        color = t.colorScheme.primary;
        icon = Icons.info_outline;
        break;
    }

    return AlertDialog(
      icon: ExcludeSemantics(child: Icon(icon, color: color, size: 40.sp)),
      title: title == null
          ? null
          : Text(title!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700)),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14.sp, height: 1.4),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        // minimumSize (not a fixed SizedBox height): keeps the 48dp touch
        // target but lets the button GROW when the user enlarges system fonts.
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            minimumSize: Size(double.infinity, 48.h),
          ),
          child: Text('ok'.tr(), style: TextStyle(fontSize: 15.sp)),
        ),
      ],
    );
  }
}
