import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../data/models/glucose_reading.dart';
import '../viewmodel/glucose_viewmodel.dart';
import '../glucose_unit.dart';
import '../../../core/utils/arabic_numerals.dart';

const _kTags = ['fasting', 'post_meal', 'random'];

/// WCAG AA colours for the clinical status label. The old raw swatches were
/// unreadable on white (orange 2.16:1, amber.shade700 2.04:1).
Color glucoseStatusColor(GlucoseStatus s, BuildContext context) {
  final c = AppColors.of(context);
  switch (s) {
    case GlucoseStatus.low:
      return c.caution;
    case GlucoseStatus.normal:
      return c.success;
    case GlucoseStatus.elevated:
      return c.warning;
    case GlucoseStatus.high:
      return c.danger;
  }
}

String glucoseStatusLabel(GlucoseStatus s) {
  switch (s) {
    case GlucoseStatus.low:
      return 'glucose_low'.tr();
    case GlucoseStatus.normal:
      return 'glucose_normal'.tr();
    case GlucoseStatus.elevated:
      return 'glucose_elevated'.tr();
    case GlucoseStatus.high:
      return 'glucose_high'.tr();
  }
}

class GlucoseScreen extends StatelessWidget {
  const GlucoseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final vm = context.watch<GlucoseViewModel>();
    final locale = context.locale.toLanguageTag();

    // Rebuild every reading on the screen the instant the unit changes: a
    // number still rendered in mg/dL beside a "mmol/L" label reads as an
    // eighteen-fold error.
    return ValueListenableBuilder<GlucoseUnit>(
      valueListenable: GlucoseUnitPref.unit,
      builder: (context, _, __) => Scaffold(
      appBar: AppBar(
        title: Text('glucose_title'.tr(), style: TextStyle(fontSize: 18.sp)),
        backgroundColor: t.scaffoldBackgroundColor,
        actions: [
          // Patients read whichever unit their own meter shows; forcing one
          // invites transcription errors. Storage stays mg/dL either way.
          PopupMenuButton<GlucoseUnit>(
            tooltip: 'glucose_unit'.tr(),
            icon: const Icon(Icons.swap_horiz),
            onSelected: GlucoseUnitPref.set,
            itemBuilder: (_) => GlucoseUnit.values
                .map((u) => PopupMenuItem<GlucoseUnit>(
                      value: u,
                      child: Row(
                        children: [
                          Icon(
                            u == GlucoseUnitPref.unit.value
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 18.sp,
                          ),
                          SizedBox(width: 8.w),
                          Text(u.label),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addReading(context),
        icon: const Icon(Icons.add),
        label: Text('glucose_add'.tr()),
      ),
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 90.h),
              children: [
                _GlucoseSummaryCard(vm: vm),
                SizedBox(height: 16.h),
                Text('glucose_history'.tr(),
                    style: t.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                SizedBox(height: 8.h),
                if (vm.items.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.h),
                    child: Center(
                      child: Text('glucose_empty'.tr(),
                          style: TextStyle(color: t.hintColor)),
                    ),
                  )
                else
                  ...vm.items.map((r) => GlucoseTile(
                        key: ValueKey(r.id),
                        reading: r,
                        locale: locale,
                        onDelete: () => vm.remove(r.id),
                      )),
              ],
            ),
      ),
    );
  }

  // Open the add dialog, then mutate AFTER it closes (mirrors the reminders
  // flow) so we never rebuild this screen while the dialog route tears down.
  Future<void> _addReading(BuildContext context) async {
    final vm = context.read<GlucoseViewModel>();
    final result = await showDialog<_GlucoseInput>(
      context: context,
      builder: (_) => const _AddGlucoseDialog(),
    );
    if (result != null) {
      vm.add(value: result.value, tag: result.tag);
    }
  }
}

class _GlucoseSummaryCard extends StatelessWidget {
  final GlucoseViewModel vm;
  const _GlucoseSummaryCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final latest = vm.latest;
    final avg = vm.recentAverage;
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: t.colorScheme.primary.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('glucose_latest'.tr(),
                    style: TextStyle(fontSize: 12.sp, color: t.hintColor)),
                SizedBox(height: 4.h),
                if (latest == null)
                  Text('—',
                      style: TextStyle(
                          fontSize: 28.sp, fontWeight: FontWeight.w700))
                else
                  Text(GlucoseUnitPref.unit.value.formatWithUnit(latest.value),
                      style: TextStyle(
                          fontSize: 26.sp, fontWeight: FontWeight.w800)),
                if (latest != null) ...[
                  SizedBox(height: 6.h),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: glucoseStatusColor(latest.status, context)
                          .withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      glucoseStatusLabel(latest.status),
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: glucoseStatusColor(latest.status, context),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (avg != null)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timeline_rounded,
                    color: t.colorScheme.primary, size: 26.sp),
                SizedBox(height: 4.h),
                Text(avg.toStringAsFixed(0),
                    style: TextStyle(
                        fontSize: 18.sp, fontWeight: FontWeight.w700)),
                Text('glucose_avg7'.tr(),
                    style: TextStyle(fontSize: 12.sp, color: t.hintColor)),
              ],
            ),
        ],
      ),
    );
  }
}

class GlucoseTile extends StatelessWidget {
  final GlucoseReading reading;
  final String locale;
  final VoidCallback onDelete;
  const GlucoseTile({
    super.key,
    required this.reading,
    required this.locale,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = reading;
    return Dismissible(
      key: ValueKey('dismiss_${r.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20.w),
        margin: EdgeInsets.only(bottom: 10.h),
        decoration: BoxDecoration(
          color: AppColors.of(context).danger.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Icon(Icons.delete_outline, color: AppColors.of(context).danger),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return true;
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: t.cardColor,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: t.dividerColor.withValues(alpha: .3)),
        ),
        child: Row(
          children: [
            Container(
              width: 10.w,
              height: 10.w,
              decoration: BoxDecoration(
                color: glucoseStatusColor(r.status, context),
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(GlucoseUnitPref.unit.value.formatWithUnit(r.value),
                      style: TextStyle(
                          fontSize: 15.sp, fontWeight: FontWeight.w700)),
                  SizedBox(height: 2.h),
                  Text(
                    '${'glucose_tag_${r.tag}'.tr()} · ${intl.DateFormat.yMMMd(locale).add_jm().format(r.dateTime)}',
                    style: TextStyle(fontSize: 12.sp, color: t.hintColor),
                  ),
                ],
              ),
            ),
            Text(glucoseStatusLabel(r.status),
                style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: glucoseStatusColor(r.status, context))),
          ],
        ),
      ),
    );
  }
}

/// Value object returned by the add dialog.
class _GlucoseInput {
  final double value;
  final String tag;
  const _GlucoseInput(this.value, this.tag);
}

class _AddGlucoseDialog extends StatefulWidget {
  const _AddGlucoseDialog();

  @override
  State<_AddGlucoseDialog> createState() => _AddGlucoseDialogState();
}

class _AddGlucoseDialogState extends State<_AddGlucoseDialog> {
  final _ctrl = TextEditingController();
  String _tag = 'fasting';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Switching units converts what is already typed instead of discarding it.
  ///
  /// Leaving the digits alone would silently change what they mean: 110 typed
  /// as mg/dL becoming 110 mmol/L, which is not a survivable blood sugar and
  /// would be stored as one. Converting keeps the reading the patient meant.
  void _switchUnit(GlucoseUnit to) {
    final from = GlucoseUnitPref.unit.value;
    if (to == from) return;
    final typed = ArabicNumerals.tryParseDouble(_ctrl.text);
    GlucoseUnitPref.set(to);
    if (typed != null && typed > 0) {
      final converted = to.fromMgdl(from.toMgdl(typed));
      // mmol/L is read to one decimal, mg/dL as a whole number.
      _ctrl.text = to == GlucoseUnit.mmoll
          ? converted.toStringAsFixed(1)
          : converted.round().toString();
    }
    setState(() {});
  }

  void _submit() {
    final u = GlucoseUnitPref.unit.value;
    final typed = ArabicNumerals.tryParseDouble(_ctrl.text);
    // Validate in the unit the patient typed, then convert. Checking the
    // converted value against mg/dL bounds would reject an ordinary 6.2 mmol/L.
    if (typed == null ||
        typed <= 0 ||
        typed < u.minInput ||
        typed > u.maxInput) {
      showAppError(context, 'glucose_invalid'.tr());
      return;
    }
    final v = u.toMgdl(typed); // stored canonically in mg/dL
    // Drop focus before the route pops so the TextField's focus node isn't
    // torn down mid-transition (avoids an InheritedElement lifecycle assert).
    FocusScope.of(context).unfocus();
    Navigator.pop(context, _GlucoseInput(v, _tag));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('glucose_add'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              // Arabic keyboards emit ٠-٩, which this filter used to swallow as the
              // patient typed. See ArabicNumerals.
              ArabicNumerals.inputFormatter,
            ],
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'glucose_value_label'.tr(),
              suffixText: GlucoseUnitPref.unit.value.label,
            ),
          ),
          SizedBox(height: 12.h),
          // The unit, changeable here rather than only from the menu behind
          // this dialog. It was shown as a suffix and nowhere else, so a
          // patient whose meter reads mmol/L had to close the dialog, find the
          // menu, switch, and start again — and the likeliest outcome of not
          // finding it is typing 6.2 into a field that means mg/dL.
          ValueListenableBuilder<GlucoseUnit>(
            valueListenable: GlucoseUnitPref.unit,
            builder: (context, unit, _) => Row(
              children: GlucoseUnit.values.map((u) {
                return Padding(
                  padding: EdgeInsetsDirectional.only(end: 8.w),
                  child: ChoiceChip(
                    label: Text(u.label),
                    selected: u == unit,
                    onSelected: (_) => _switchUnit(u),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 16.h),
          Text('glucose_when'.tr(), style: TextStyle(fontSize: 13.sp)),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            children: _kTags.map((tg) {
              return ChoiceChip(
                label: Text('glucose_tag_$tg'.tr()),
                selected: _tag == tg,
                onSelected: (_) => setState(() => _tag = tg),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr()),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text('save'.tr()),
        ),
      ],
    );
  }
}
