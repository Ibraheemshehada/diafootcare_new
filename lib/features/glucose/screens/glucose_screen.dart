import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../../../data/models/glucose_reading.dart';
import '../viewmodel/glucose_viewmodel.dart';

const _kTags = ['fasting', 'post_meal', 'random'];

Color glucoseStatusColor(GlucoseStatus s) {
  switch (s) {
    case GlucoseStatus.low:
      return Colors.orange;
    case GlucoseStatus.normal:
      return Colors.green;
    case GlucoseStatus.elevated:
      return Colors.amber.shade700;
    case GlucoseStatus.high:
      return Colors.red;
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

    return Scaffold(
      appBar: AppBar(
        title: Text('glucose_title'.tr(), style: TextStyle(fontSize: 18.sp)),
        backgroundColor: t.scaffoldBackgroundColor,
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
                  Text('${latest.value.toStringAsFixed(0)}  mg/dL',
                      style: TextStyle(
                          fontSize: 26.sp, fontWeight: FontWeight.w800)),
                if (latest != null) ...[
                  SizedBox(height: 6.h),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: glucoseStatusColor(latest.status)
                          .withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      glucoseStatusLabel(latest.status),
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: glucoseStatusColor(latest.status),
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
                    style: TextStyle(fontSize: 10.sp, color: t.hintColor)),
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
          color: Colors.red.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red),
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
                color: glucoseStatusColor(r.status),
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${r.value.toStringAsFixed(0)} mg/dL',
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
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: glucoseStatusColor(r.status))),
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

  void _submit() {
    final v = double.tryParse(_ctrl.text.trim());
    if (v == null || v <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('glucose_invalid'.tr())),
      );
      return;
    }
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
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'glucose_value_label'.tr(),
              suffixText: 'mg/dL',
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
