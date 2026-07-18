import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/sync_service.dart';
import '../theme/app_colors.dart';

/// Shows whether the participant's records have reached the study, and lets
/// them push them now.
///
/// This app records clinical data that only matters once it is on the server,
/// and it can sit offline for days. Without a visible state, "did my scan
/// actually go anywhere?" is unanswerable — so the indicator is always present
/// rather than appearing only when something is wrong.
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  Future<void> _syncNow(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await SyncService.I.syncNow();

    if (!context.mounted) return;

    // Deliberately quiet feedback: the icon already changes, and this app uses
    // dialogs for things the user must act on. A completed background upload is
    // not one of them.
    final text = result.skipped
        ? 'sync_offline'.tr()
        : (result.failed > 0 ? 'sync_partial'.tr() : 'sync_done'.tr());

    messenger?.showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    return ValueListenableBuilder<bool>(
      valueListenable: SyncService.I.syncing,
      builder: (context, syncing, _) {
        return ValueListenableBuilder<int>(
          valueListenable: SyncService.I.pendingCount,
          builder: (context, pending, _) {
            final (icon, colour, label) = switch ((syncing, pending)) {
              (true, _) => (
                  Icons.cloud_sync_outlined,
                  theme.colorScheme.primary,
                  'sync_in_progress'.tr(),
                ),
              (false, 0) => (
                  Icons.cloud_done_outlined,
                  colors.success,
                  'sync_up_to_date'.tr(),
                ),
              _ => (
                  Icons.cloud_upload_outlined,
                  colors.caution,
                  'sync_pending'.tr(namedArgs: {'n': '$pending'}),
                ),
            };

            return Semantics(
              button: true,
              // The label carries the state, so a screen-reader user is not left
              // guessing at an icon whose meaning is colour-coded.
              label: label,
              child: Tooltip(
                message: label,
                child: InkWell(
                  onTap: syncing ? null : () => _syncNow(context),
                  borderRadius: BorderRadius.circular(24.r),
                  child: ConstrainedBox(
                    // 48dp minimum touch target, matching the rest of the app.
                    constraints: BoxConstraints(minWidth: 48.w, minHeight: 48.h),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (syncing)
                            // Fixed size rather than a scaled one: this rendered
                            // as a two-pixel dot when the scale factor was applied.
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(colour),
                              ),
                            )
                          else
                            Icon(icon, color: colour, size: 24.sp),

                          // The count sits beside the icon rather than on top of
                          // it. An overlay badge covered the glyph, and this app
                          // is built for older users who should not have to
                          // decode a partly hidden symbol.
                          if (!syncing && pending > 0) ...[
                            SizedBox(width: 4.w),
                            Text(
                              pending > 99 ? '99+' : '$pending',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colour,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.sp,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
