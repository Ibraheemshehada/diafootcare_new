import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../services/infection_triage.dart';

/// The five IWGDF/IDSA signs a camera cannot capture.
///
/// Only signs the **camera cannot see** are asked. Erythema is left to the
/// image model, which judges redness more consistently than an untrained
/// observer estimating "wider than half a centimetre". Warmth, tenderness and
/// smell are invisible to a lens, and they are exactly the signs the criteria
/// need — see [InfectionSigns].
///
/// Presented as tappable cards rather than Yes/No pairs: ten buttons is a lot
/// of reading for an elderly patient, and the pairs made every question look
/// equally weighted when most people answer "no" to all of them. Tapping a card
/// means "yes, I have this".
///
/// **A reported sign is amber, not green.** This list borrows the layout of the
/// self-care checklist the patient already knows, but it means the opposite:
/// there a tick is an accomplishment, here it is a symptom. Colouring a
/// reported sign green would read as good news.
///
/// A sign is *reviewed* once the patient has decided about it — by tapping it
/// (present) or via "none of these apply" (all absent). Reviewed-and-absent is
/// not the same as never looked at: returning `null` from this screen means
/// "no answers", never "all no", and the result screen says so.
class InfectionChecklistScreen extends StatefulWidget {
  const InfectionChecklistScreen({super.key});

  @override
  State<InfectionChecklistScreen> createState() =>
      _InfectionChecklistScreenState();
}

enum _Sign { discharge, warmth, swelling, tenderness, systemic }

class _InfectionChecklistScreenState extends State<InfectionChecklistScreen> {
  /// Signs the patient marked as present.
  final Set<_Sign> _present = {};

  /// Signs the patient has actually decided about. A sign can be reviewed and
  /// absent, which is different from never having been considered.
  final Set<_Sign> _reviewed = {};

  bool get _allReviewed => _reviewed.length == _Sign.values.length;

  void _toggle(_Sign s) {
    setState(() {
      _reviewed.add(s);
      if (!_present.remove(s)) _present.add(s);
    });
  }

  void _markNoneApply() {
    setState(() {
      _present.clear();
      _reviewed.addAll(_Sign.values);
    });
  }

  InfectionSigns get _signs => InfectionSigns(
        purulentDischarge: _present.contains(_Sign.discharge),
        warmth: _present.contains(_Sign.warmth),
        swelling: _present.contains(_Sign.swelling),
        tenderness: _present.contains(_Sign.tenderness),
        systemicUnwell: _present.contains(_Sign.systemic),
      );

  static const Map<_Sign, (IconData, String, String)> _meta = {
    _Sign.discharge: (
      Icons.water_drop_outlined,
      'infection_q_discharge',
      'infection_q_discharge_hint'
    ),
    _Sign.warmth: (
      Icons.thermostat,
      'infection_q_warmth',
      'infection_q_warmth_hint'
    ),
    _Sign.swelling: (
      Icons.expand_outlined,
      'infection_q_swelling',
      'infection_q_swelling_hint'
    ),
    _Sign.tenderness: (
      Icons.back_hand_outlined,
      'infection_q_tenderness',
      'infection_q_tenderness_hint'
    ),
    _Sign.systemic: (
      Icons.sick_outlined,
      'infection_q_systemic',
      'infection_q_systemic_hint'
    ),
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('infection_check_title'.tr())),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                children: [
                  _ProgressHeader(
                    reviewed: _reviewed.length,
                    total: _Sign.values.length,
                    found: _present.length,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'infection_check_intro'.tr(),
                    style:
                        t.textTheme.bodyMedium?.copyWith(color: t.hintColor),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'infection_check_howto'.tr(),
                    style: t.textTheme.bodySmall?.copyWith(color: t.hintColor),
                  ),
                  SizedBox(height: 16.h),
                  for (final s in _Sign.values) ...[
                    _SignCard(
                      icon: _meta[s]!.$1,
                      title: _meta[s]!.$2.tr(),
                      hint: _meta[s]!.$3.tr(),
                      present: _present.contains(s),
                      reviewed: _reviewed.contains(s),
                      onTap: () => _toggle(s),
                    ),
                    SizedBox(height: 10.h),
                  ],
                  SizedBox(height: 4.h),
                  // Most patients have none of these. Making them tap five
                  // cards to say so invites tapping through without reading;
                  // one honest button is faster and less likely to produce a
                  // careless answer.
                  OutlinedButton.icon(
                    onPressed: _markNoneApply,
                    icon: const Icon(Icons.done_all),
                    label: Text('infection_none_apply'.tr()),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(double.infinity, 48.h),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 12.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: FilledButton(
                      // Enabled only once every sign has been decided, so a
                      // half-answered list cannot be read as "all clear".
                      onPressed: _allReviewed
                          ? () => Navigator.of(context).pop(_signs)
                          : null,
                      child: Text(
                        _allReviewed
                            ? 'continue'.tr()
                            : 'infection_answer_all'.tr(),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'skip'.tr(),
                      style: TextStyle(color: t.hintColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reviewed-so-far ring, mirroring the self-care header the patient already knows.
class _ProgressHeader extends StatelessWidget {
  final int reviewed, total, found;
  const _ProgressHeader({
    required this.reviewed,
    required this.total,
    required this.found,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = AppColors.of(context);
    final done = reviewed == total;
    // Green only when everything is reviewed AND nothing was found. A complete
    // list with signs on it is not a success state.
    final ring =
        !done ? t.colorScheme.primary : (found == 0 ? c.success : c.warning);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: t.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'infection_progress_title'.tr(),
                  style: t.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4.h),
                Text(
                  'infection_progress_body'.tr(
                    namedArgs: {'n': '$reviewed', 'total': '$total'},
                  ),
                  style: t.textTheme.bodySmall?.copyWith(color: t.hintColor),
                ),
                if (done && found > 0) ...[
                  SizedBox(height: 6.h),
                  Text(
                    'infection_progress_found'.tr(namedArgs: {'n': '$found'}),
                    style: t.textTheme.bodySmall?.copyWith(
                      color: c.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 12.w),
          SizedBox(
            width: 56.w,
            height: 56.w,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: total == 0 ? 0 : reviewed / total,
                    strokeWidth: 5,
                    backgroundColor: t.dividerColor,
                    valueColor: AlwaysStoppedAnimation(ring),
                  ),
                ),
                Text(
                  '$reviewed/$total',
                  style: t.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignCard extends StatelessWidget {
  final IconData icon;
  final String title, hint;
  final bool present, reviewed;
  final VoidCallback onTap;

  const _SignCard({
    required this.icon,
    required this.title,
    required this.hint,
    required this.present,
    required this.reviewed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = AppColors.of(context);
    // Amber when reported, muted-positive when reviewed and absent, neutral
    // when untouched — so what is left to decide is visible at a glance.
    final accent = present
        ? c.warning
        : (reviewed ? c.success : t.colorScheme.onSurfaceVariant);

    return Semantics(
      button: true,
      checked: present,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: present
                ? c.warning.withValues(alpha: 0.10)
                : t.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            border: Border.all(
              color:
                  present ? c.warning.withValues(alpha: 0.55) : t.dividerColor,
              width: present ? 1.4 : 1,
            ),
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                present
                    ? Icons.check_circle
                    : (reviewed
                        ? Icons.remove_circle_outline
                        : Icons.circle_outlined),
                color: accent,
                size: 24.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: t.textTheme.bodyLarge?.copyWith(
                        fontWeight:
                            present ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      hint,
                      style:
                          t.textTheme.bodySmall?.copyWith(color: t.hintColor),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Icon(icon, color: accent.withValues(alpha: 0.65), size: 20.sp),
            ],
          ),
        ),
      ),
    );
  }
}
