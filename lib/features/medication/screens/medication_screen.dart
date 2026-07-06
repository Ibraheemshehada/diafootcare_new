import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../data/models/medication.dart';
import '../viewmodel/medication_viewmodel.dart';

class MedicationScreen extends StatelessWidget {
  const MedicationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final vm = context.watch<MedicationViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text('medication_title'.tr(), style: TextStyle(fontSize: 18.sp)),
        backgroundColor: t.scaffoldBackgroundColor,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addMedication(context),
        icon: const Icon(Icons.add),
        label: Text('medication_add'.tr()),
      ),
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 90.h),
              children: [
                _AdherenceCard(vm: vm),
                SizedBox(height: 16.h),
                Text('medication_list'.tr(),
                    style: t.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                SizedBox(height: 8.h),
                if (vm.items.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.h),
                    child: Center(
                      child: Text('medication_empty'.tr(),
                          style: TextStyle(color: t.hintColor)),
                    ),
                  )
                else
                  ...vm.items.map((m) => MedicationTile(
                        key: ValueKey(m.id),
                        med: m,
                        takenFlags: List.generate(
                            m.timesPerDay, (i) => vm.isDoseTaken(m.id, i)),
                        onToggle: (i) => vm.toggleDose(m.id, i),
                        onDelete: () => vm.removeMedication(m.id),
                      )),
              ],
            ),
    );
  }

  Future<void> _addMedication(BuildContext context) async {
    final vm = context.read<MedicationViewModel>();
    final result = await showDialog<_MedInput>(
      context: context,
      builder: (_) => const _AddMedicationDialog(),
    );
    if (result != null) {
      vm.addMedication(
        name: result.name,
        dosage: result.dosage,
        timesPerDay: result.timesPerDay,
      );
    }
  }
}

class _AdherenceCard extends StatelessWidget {
  final MedicationViewModel vm;
  const _AdherenceCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final pct = vm.adherenceTodayPct;
    final color = pct >= 80
        ? Colors.green
        : (pct >= 50 ? Colors.amber.shade700 : Colors.red);
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: t.colorScheme.primary.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64.w,
            height: 64.w,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 64.w,
                  height: 64.w,
                  child: CircularProgressIndicator(
                    value: pct / 100,
                    strokeWidth: 6,
                    backgroundColor: t.dividerColor.withValues(alpha: .3),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Text('$pct%',
                    style: TextStyle(
                        fontSize: 14.sp, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('medication_adherence_today'.tr(),
                    style: TextStyle(
                        fontSize: 13.sp, fontWeight: FontWeight.w700)),
                SizedBox(height: 4.h),
                Text(
                  'medication_doses_taken'.tr(namedArgs: {
                    'taken': vm.takenToday.toString(),
                    'total': vm.scheduledToday.toString(),
                  }),
                  style: TextStyle(fontSize: 12.sp, color: t.hintColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MedicationTile extends StatelessWidget {
  final Medication med;
  final List<bool> takenFlags;
  final ValueChanged<int> onToggle;
  final VoidCallback onDelete;
  const MedicationTile({
    super.key,
    required this.med,
    required this.takenFlags,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Dismissible(
      key: ValueKey('med_dismiss_${med.id}'),
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
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: t.cardColor,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: t.dividerColor.withValues(alpha: .3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medication_outlined,
                    color: t.colorScheme.primary, size: 22.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(med.name,
                          style: TextStyle(
                              fontSize: 15.sp, fontWeight: FontWeight.w700)),
                      if (med.dosage.trim().isNotEmpty)
                        Text(med.dosage,
                            style:
                                TextStyle(fontSize: 12.sp, color: t.hintColor)),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: List.generate(med.timesPerDay, (i) {
                final taken = i < takenFlags.length && takenFlags[i];
                return ChoiceChip(
                  avatar: Icon(
                    taken ? Icons.check_circle : Icons.circle_outlined,
                    size: 18.sp,
                    color: taken ? Colors.white : t.colorScheme.primary,
                  ),
                  label: Text('medication_dose'.tr(namedArgs: {
                    'n': (i + 1).toString(),
                  })),
                  selected: taken,
                  onSelected: (_) => onToggle(i),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedInput {
  final String name;
  final String dosage;
  final int timesPerDay;
  const _MedInput(this.name, this.dosage, this.timesPerDay);
}

class _AddMedicationDialog extends StatefulWidget {
  const _AddMedicationDialog();

  @override
  State<_AddMedicationDialog> createState() => _AddMedicationDialogState();
}

class _AddMedicationDialogState extends State<_AddMedicationDialog> {
  final _nameCtrl = TextEditingController();
  final _doseCtrl = TextEditingController();
  int _timesPerDay = 1;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _doseCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('medication_name_required'.tr())),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    Navigator.pop(
        context, _MedInput(name, _doseCtrl.text.trim(), _timesPerDay));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('medication_add'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'medication_name'.tr(),
              ),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _doseCtrl,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'medication_dosage'.tr(),
                hintText: 'medication_dosage_hint'.tr(),
              ),
              inputFormatters: [LengthLimitingTextInputFormatter(40)],
            ),
            SizedBox(height: 16.h),
            Text('medication_times_per_day'.tr(),
                style: TextStyle(fontSize: 13.sp)),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              children: List.generate(4, (i) {
                final n = i + 1;
                return ChoiceChip(
                  label: Text('$n'),
                  selected: _timesPerDay == n,
                  onSelected: (_) => setState(() => _timesPerDay = n),
                );
              }),
            ),
          ],
        ),
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
