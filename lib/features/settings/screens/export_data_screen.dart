import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../viewmodel/export_data_viewmodel.dart';

class ExportDataScreen extends StatelessWidget {
  const ExportDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return ChangeNotifierProvider(
      create: (_) => ExportDataViewModel(),
      child: Consumer<ExportDataViewModel>(
        builder: (context, vm, _) {
          return Scaffold(
            appBar: AppBar(title: Text('export_title'.tr())),
            body: ListView(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
              children: [
                Text('export_subtitle'.tr(), style: t.textTheme.bodyMedium),
                SizedBox(height: 12.h),

                // Datasets
                CheckboxListTile(
                  value: vm.woundAI,
                  onChanged: (v) => vm.toggleWoundAI(v ?? false),
                  title: Text('ds_wound_ai'.tr()),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: t.colorScheme.primary,
                ),
                CheckboxListTile(
                  value: vm.glucose,
                  onChanged: (v) => vm.toggleGlucose(v ?? false),
                  title: Text('ds_glucose'.tr()),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: t.colorScheme.primary,
                ),
                CheckboxListTile(
                  value: vm.notes,
                  onChanged: (v) => vm.toggleNotes(v ?? false),
                  title: Text('ds_notes'.tr()),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: t.colorScheme.primary,
                ),
                CheckboxListTile(
                  value: vm.medication,
                  onChanged: (v) => vm.toggleMedication(v ?? false),
                  title: Text('ds_medication'.tr()),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: t.colorScheme.primary,
                ),
                CheckboxListTile(
                  value: vm.reminders,
                  onChanged: (v) => vm.toggleReminders(v ?? false),
                  title: Text('ds_reminders'.tr()),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: t.colorScheme.primary,
                ),
                CheckboxListTile(
                  value: vm.allSelected,
                  onChanged: (v) => vm.toggleAll(v ?? false),
                  title: Text('ds_all'.tr()),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: t.colorScheme.primary,
                ),

                SizedBox(height: 16.h),
                Text('choose_format'.tr(), style: t.textTheme.bodyMedium),
                SizedBox(height: 8.h),

                RadioListTile<ExportFormat>(
                  value: ExportFormat.pdf,
                  groupValue: vm.format,
                  onChanged: (v) => vm.setFormat(v!),
                  title: Text('fmt_pdf'.tr()),
                  contentPadding: EdgeInsets.zero,
                  activeColor: t.colorScheme.primary,
                ),
                RadioListTile<ExportFormat>(
                  value: ExportFormat.csv,
                  groupValue: vm.format,
                  onChanged: (v) => vm.setFormat(v!),
                  title: Text('fmt_csv'.tr()),
                  contentPadding: EdgeInsets.zero,
                  activeColor: t.colorScheme.primary,
                ),
                RadioListTile<ExportFormat>(
                  value: ExportFormat.xlsx,
                  groupValue: vm.format,
                  onChanged: (v) => vm.setFormat(v!),
                  title: Text('fmt_excel'.tr()),
                  contentPadding: EdgeInsets.zero,
                  activeColor: t.colorScheme.primary,
                ),

                SizedBox(height: 20.h),
                Center(
                  child: SizedBox(
                    width: 230.w,
                    height: 48.h,
                    child: FilledButton(
                      onPressed: vm.hasAny
                          ? () async {
                        await vm.export();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('export_preparing'.tr())),
                        );
                      }
                          : null,
                      child: Text('export_download'.tr(),
                          style: TextStyle(fontSize: 14.sp)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
