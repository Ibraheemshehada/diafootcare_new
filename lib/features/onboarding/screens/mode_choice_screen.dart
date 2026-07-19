import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/services/app_mode_service.dart';
import '../../../core/services/model_download_service.dart';
import '../../../core/theme/app_colors.dart';
import 'model_download_screen.dart';

/// Where the participant chooses how the app analyses their wound.
///
/// Shown once, after consent and before the app opens. Both options are
/// presented as legitimate — this is a genuine trade-off, not an upsell — and
/// the download size is stated plainly rather than discovered after the choice.
class ModeChoiceScreen extends StatefulWidget {
  /// When true the screen cannot be dismissed; this is the first-run gate.
  final bool blocking;

  const ModeChoiceScreen({super.key, this.blocking = true});

  @override
  State<ModeChoiceScreen> createState() => _ModeChoiceScreenState();
}

class _ModeChoiceScreenState extends State<ModeChoiceScreen> {
  AppMode? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Reopened from Profile: start on whatever is already in force.
    AppModeService.I.current().then((m) {
      if (mounted && m != null) setState(() => _selected = m);
    });
  }

  Future<void> _confirm() async {
    if (_selected == null || _saving) return;
    setState(() => _saving = true);

    await AppModeService.I.set(_selected!);

    // Offline is not a setting, it is a download. Sending the participant
    // straight into it keeps the promise the card just made, and the download
    // screen can fall back to online if they change their mind there.
    if (_selected == AppMode.offline &&
        !await ModelDownloadService.I.isInstalled()) {
      if (!mounted) return;
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const ModelDownloadScreen(fromSetup: true),
        ),
      );
    }

    if (!mounted) return;
    Navigator.pop(context, await AppModeService.I.current());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !widget.blocking,
      child: Scaffold(
        appBar: AppBar(
          title: Text('mode_title'.tr()),
          automaticallyImplyLeading: !widget.blocking,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('mode_intro'.tr(),
                          style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
                      SizedBox(height: 20.h),

                      _ModeCard(
                        mode: AppMode.online,
                        icon: Icons.cloud_outlined,
                        selected: _selected == AppMode.online,
                        onTap: () => setState(() => _selected = AppMode.online),
                      ),
                      SizedBox(height: 12.h),
                      _ModeCard(
                        mode: AppMode.offline,
                        icon: Icons.cloud_off_outlined,
                        selected: _selected == AppMode.offline,
                        onTap: () => setState(() => _selected = AppMode.offline),
                      ),

                      SizedBox(height: 16.h),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 18.sp, color: theme.colorScheme.onSurfaceVariant),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text('mode_changeable'.tr(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: 48.h),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (_selected != null && !_saving) ? _confirm : null,
                      child: _saving
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text('mode_continue'.tr()),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final AppMode mode;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.mode,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final key = mode.name; // 'online' | 'offline'

    return Semantics(
      button: true,
      selected: selected,
      label: '${'mode_${key}_title'.tr()}. ${'mode_${key}_body'.tr()}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              // Selection is carried by a thick border *and* a check icon, not
              // colour alone.
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: selected ? 2.5 : 1,
            ),
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.06)
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28.sp, color: theme.colorScheme.primary),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('mode_${key}_title'.tr(),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4.h),
                    Text('mode_${key}_body'.tr(),
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
                    SizedBox(height: 10.h),

                    // The trade-off, stated before the choice rather than
                    // discovered after it.
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 6.h,
                      children: [
                        _Tag(
                          icon: Icons.download_outlined,
                          label: 'mode_${key}_download'.tr(),
                          color: mode == AppMode.offline
                              ? colors.caution
                              : colors.success,
                        ),
                        _Tag(
                          icon: Icons.wifi_outlined,
                          label: 'mode_${key}_connection'.tr(),
                          color: mode == AppMode.offline
                              ? colors.success
                              : colors.caution,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              // Always drawn, not only once chosen. An empty circle says "this
              // is one of a set you pick from" before the first tap; a check
              // that appears only after selecting leaves the cards looking like
              // two blocks of text until you guess that they are tappable.
              _SelectionDot(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Tag({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.sp, color: color),
        SizedBox(width: 4.w),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// The circle on a mode card.
///
/// Empty when unselected, filled with a tick when chosen. Kept a plain widget
/// rather than a Radio so the whole card stays the tap target — a 24 px radio
/// is a poor thing to ask an older patient with neuropathy to hit accurately.
class _SelectionDot extends StatelessWidget {
  final bool selected;

  const _SelectionDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 24.w,
      height: 24.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? theme.colorScheme.primary : Colors.transparent,
        border: Border.all(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
          width: 2,
        ),
      ),
      // The tick carries the state alongside the fill, so the difference is not
      // colour alone.
      child: selected
          ? Icon(Icons.check, size: 16.sp, color: theme.colorScheme.onPrimary)
          : null,
    );
  }
}
