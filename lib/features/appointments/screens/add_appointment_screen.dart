import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../../../data/models/appointment.dart';
import '../viewmodel/appointments_viewmodel.dart';

class AddAppointmentScreen extends StatefulWidget {
  const AddAppointmentScreen({super.key});

  @override
  State<AddAppointmentScreen> createState() => _AddAppointmentScreenState();
}

class _AddAppointmentScreenState extends State<AddAppointmentScreen> {
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  late DateTime _date;
  late TimeOfDay _time;
  int _reminderLead = 1440; // default: 1 day before

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().add(const Duration(hours: 1));
    _date = DateTime(now.year, now.month, now.day);
    _time = TimeOfDay(hour: now.hour, minute: 0);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  DateTime get _combined =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(now) ? now : _date,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
      locale: context.locale,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('appt_title_required'.tr())),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    await context.read<AppointmentsViewModel>().add(
          title: title,
          dateTime: _combined,
          location: _locationCtrl.text.trim(),
          notes: _notesCtrl.text.trim(),
          reminderLead: _reminderLead,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('appt_saved'.tr()),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final locale = context.locale.toLanguageTag();

    return Scaffold(
      appBar: AppBar(title: Text('appt_add'.tr())),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
        children: [
          _label('appt_field_title'.tr(), t),
          SizedBox(height: 6.h),
          TextField(
            controller: _titleCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: 'appt_field_title_hint'.tr(),
            ),
          ),
          SizedBox(height: 16.h),
          _PickerRow(
            icon: Icons.event_outlined,
            label: 'appt_field_date'.tr(),
            value: intl.DateFormat.yMMMMEEEEd(locale).format(_date),
            onTap: _pickDate,
          ),
          SizedBox(height: 10.h),
          _PickerRow(
            icon: Icons.schedule_outlined,
            label: 'appt_field_time'.tr(),
            value: _time.format(context),
            onTap: _pickTime,
          ),
          SizedBox(height: 16.h),
          _label('appt_field_location'.tr(), t),
          SizedBox(height: 6.h),
          TextField(
            controller: _locationCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: 'appt_field_location_hint'.tr(),
              prefixIcon: const Icon(Icons.place_outlined),
            ),
          ),
          SizedBox(height: 16.h),
          _label('appt_field_notes'.tr(), t),
          SizedBox(height: 6.h),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          SizedBox(height: 16.h),
          _label('appt_reminder'.tr(), t),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: appointmentLeadOptions.map((m) {
              return ChoiceChip(
                label: Text(appointmentLeadKey(m).tr()),
                selected: _reminderLead == m,
                onSelected: (_) => setState(() => _reminderLead = m),
              );
            }).toList(),
          ),
          SizedBox(height: 28.h),
          SizedBox(
            height: 50.h,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text('appt_save'.tr(), style: TextStyle(fontSize: 16.sp)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, ThemeData t) =>
      Text(text, style: t.textTheme.labelLarge);
}

class _PickerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _PickerRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: t.dividerColor.withValues(alpha: .5)),
          ),
          child: Row(
            children: [
              Icon(icon, color: t.colorScheme.primary, size: 20.sp),
              SizedBox(width: 12.w),
              Text('$label:  ',
                  style: TextStyle(fontSize: 13.sp, color: t.hintColor)),
              Expanded(
                child: Text(value,
                    style: TextStyle(
                        fontSize: 14.sp, fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.edit_outlined, size: 18.sp, color: t.hintColor),
            ],
          ),
        ),
      ),
    );
  }
}
