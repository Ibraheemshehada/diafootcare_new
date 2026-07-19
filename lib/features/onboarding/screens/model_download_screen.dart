import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/services/app_mode_service.dart';
import '../../../core/services/model_download_service.dart';
import '../../../core/theme/app_colors.dart';

/// Formats bytes the way a phone's storage settings would.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB'];
  var v = bytes / 1024;
  var u = 0;
  while (v >= 1024 && u < units.length - 1) {
    v /= 1024;
    u++;
  }
  return '${v < 10 ? v.toStringAsFixed(1) : v.round()} ${units[u]}';
}

/// A rough, honest duration. Deliberately coarse — claiming "2 min 14 sec"
/// implies a precision a mobile connection does not have.
String formatRemaining(int seconds) {
  if (seconds < 60) return 'dl_seconds_left'.tr();
  final minutes = (seconds / 60).ceil();
  if (minutes < 60) return 'dl_minutes_left'.tr(args: ['$minutes']);
  return 'dl_hours_left'.tr(args: ['${(minutes / 60).ceil()}']);
}

/// Downloads the offline analysis bundle, with progress the participant can act on.
class ModelDownloadScreen extends StatefulWidget {
  /// When true, leaving without finishing falls back to online mode rather than
  /// stranding the participant in a half-configured app.
  final bool fromSetup;

  const ModelDownloadScreen({super.key, this.fromSetup = false});

  @override
  State<ModelDownloadScreen> createState() => _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends State<ModelDownloadScreen> {
  final _service = ModelDownloadService.I;
  late DownloadProgress _p = _service.progress;
  StreamSubscription<DownloadProgress>? _sub;
  bool _installed = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _sub = _service.stream.listen((p) {
      if (!mounted) return;
      setState(() => _p = p);
      if (p.state == DownloadState.complete) _onComplete();
    });
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final installed = await _service.isInstalled();
    if (!mounted) return;
    setState(() {
      _installed = installed;
      _loading = false;
    });
    // Coming from setup with nothing installed, start immediately: the
    // participant already chose offline, and making them tap again to begin
    // what they just asked for is friction with no decision behind it.
    if (!installed && widget.fromSetup) unawaited(_service.start());
  }

  Future<void> _onComplete() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    if (widget.fromSetup) {
      Navigator.pop(context, true);
    } else {
      setState(() => _installed = true);
    }
  }

  /// Leaving setup unfinished must not leave the app claiming an offline
  /// capability it does not have.
  Future<void> _useOnlineInstead() async {
    _service.pause();
    await AppModeService.I.set(AppMode.online);
    if (mounted) Navigator.pop(context, false);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('dl_delete_title'.tr()),
        content: Text('dl_delete_body'.tr()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: Text('cancel'.tr())),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: Text('dl_delete'.tr())),
        ],
      ),
    );
    if (ok != true) return;

    await _service.deleteDownloaded();
    await AppModeService.I.set(AppMode.online);
    if (mounted) setState(() => _installed = false);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('dl_title'.tr()),
        automaticallyImplyLeading: !widget.fromSetup,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: EdgeInsets.all(20.w),
                child: _installed ? _installedView(theme) : _downloadView(theme),
              ),
      ),
    );
  }

  Widget _installedView(ThemeData theme) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, color: colors.success, size: 28.sp),
            SizedBox(width: 10.w),
            Expanded(
              child: Text('dl_ready'.tr(),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Text('dl_ready_body'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
            label: Text('dl_delete_free'.tr(
                args: [formatBytes(_service.manifest?.totalBytes ?? 0)])),
          ),
        ),
      ],
    );
  }

  Widget _downloadView(ThemeData theme) {
    final colors = AppColors.of(context);
    final failed = _p.state == DownloadState.failed;
    final paused = _p.state == DownloadState.paused;
    final total = _p.total > 0 ? _p.total : (_service.manifest?.totalBytes ?? 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('dl_intro'.tr(args: [formatBytes(total)]),
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
        SizedBox(height: 24.h),

        // Percentage first: it is the one number people look for.
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('${(_p.fraction * 100).floor()}%',
                style: theme.textTheme.displaySmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(width: 10.w),
            if (_p.fileCount > 0 && _p.state == DownloadState.downloading)
              Text('dl_file_of'.tr(args: ['${_p.fileIndex}', '${_p.fileCount}']),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        SizedBox(height: 12.h),

        ClipRRect(
          borderRadius: BorderRadius.circular(6.r),
          child: LinearProgressIndicator(
            // A determinate bar during verification would look frozen; the
            // indeterminate sweep says "still working" truthfully.
            value: _p.state == DownloadState.verifying ? null : _p.fraction,
            minHeight: 10.h,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: failed ? colors.danger : theme.colorScheme.primary,
          ),
        ),
        SizedBox(height: 10.h),

        Text(_statusLine(),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),

        if (failed) ...[
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: colors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 18.sp, color: colors.danger),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(_p.error ?? 'dl_failed'.tr(),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colors.danger)),
                ),
              ],
            ),
          ),
        ],

        SizedBox(height: 20.h),

        // The reassurance that makes pausing safe to do.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline,
                size: 18.sp, color: theme.colorScheme.onSurfaceVariant),
            SizedBox(width: 8.w),
            Expanded(
              child: Text('dl_resumable'.tr(),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
          ],
        ),

        const Spacer(),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _p.state == DownloadState.downloading ||
                    _p.state == DownloadState.checking
                ? _service.pause
                : (_p.state == DownloadState.verifying ? null : _service.start),
            icon: Icon(_p.state == DownloadState.downloading ||
                    _p.state == DownloadState.checking
                ? Icons.pause
                : (failed ? Icons.refresh : Icons.download)),
            label: Text(
              _p.state == DownloadState.downloading ||
                      _p.state == DownloadState.checking
                  ? 'dl_pause'.tr()
                  : failed
                      ? 'dl_retry'.tr()
                      : paused || _p.received > 0
                          ? 'dl_resume'.tr()
                          : 'dl_start'.tr(),
            ),
          ),
        ),
        SizedBox(height: 8.h),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _useOnlineInstead,
            child: Text('dl_use_online'.tr()),
          ),
        ),
      ],
    );
  }

  String _statusLine() {
    switch (_p.state) {
      case DownloadState.checking:
        return 'dl_checking'.tr();
      case DownloadState.verifying:
        return 'dl_verifying'.tr();
      case DownloadState.paused:
        return 'dl_paused'.tr(
            args: [formatBytes(_p.received), formatBytes(_p.total)]);
      case DownloadState.failed:
        return 'dl_kept'.tr(args: [formatBytes(_p.received)]);
      case DownloadState.complete:
        return 'dl_done'.tr();
      case DownloadState.downloading:
        final base = '${formatBytes(_p.received)} / ${formatBytes(_p.total)}';
        final left = _p.secondsRemaining;
        // The ETA is appended only once it means something, rather than
        // flickering wild guesses during the first seconds.
        return left == null ? base : '$base  ·  ${formatRemaining(left)}';
      case DownloadState.idle:
        return 'dl_not_started'.tr();
    }
  }
}
