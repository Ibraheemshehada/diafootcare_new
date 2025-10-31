// import 'package:easy_localization/easy_localization.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:intl/intl.dart' as intl;
// import '../../../data/models/reminder.dart';
// import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
// import '../../../core/services/notification_service.dart';
//
// enum ReminderKind { medication, wound, photo, other }
// enum RepeatMode { once, daily, custom }
//
// class AddReminderScreen extends StatefulWidget {
//   const AddReminderScreen({super.key});
//
//   @override
//   State<AddReminderScreen> createState() => _AddReminderScreenState();
// }
//
// class _AddReminderScreenState extends State<AddReminderScreen> {
//   final _formKey = GlobalKey<FormState>();
//   DateTime _combineDateAndTime(DateTime date, TimeOfDay t) =>
//       DateTime(date.year, date.month, date.day, t.hour, t.minute);
//   // fields
//   String _label = '';
//   ReminderKind _kind = ReminderKind.photo;
//   RepeatMode _repeat = RepeatMode.once;
//
//   // optional medication-specific
//   String _medName = '';
//   String _dosage = '';
//
//   // scheduling
//   DateTime? _oneDate = DateTime.now();
//   TimeOfDay _time = TimeOfDay.now();
//   final Set<int> _weekdays = { DateTime.monday }; // for custom
//
//   // helpers
//   String _id() => DateTime.now().millisecondsSinceEpoch.toString();
//
//   Future<void> _pickDate() async {
//     final now = DateTime.now();
//     final initial = _oneDate ?? now;
//     final picked = await showDatePicker(
//       context: context,
//       initialDate: initial,
//       firstDate: now.subtract(const Duration(days: 365)),
//       lastDate: now.add(const Duration(days: 365 * 3)),
//       locale: context.locale,
//     );
//     if (picked != null) setState(() => _oneDate = picked);
//   }
//
//   Future<void> _pickTime() async {
//     final picked = await showTimePicker(context: context, initialTime: _time, builder: (ctx, child) {
//       // respect dark/light
//       return MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false), child: child!);
//     });
//     if (picked != null) setState(() => _time = picked);
//   }
//
//   String _kindLabel(ReminderKind k) {
//     switch (k) {
//       case ReminderKind.medication: return 'type_medication'.tr();
//       case ReminderKind.wound:      return 'type_wound'.tr();
//       case ReminderKind.photo:      return 'type_photo'.tr();
//       case ReminderKind.other:      return 'type_other'.tr();
//     }
//   }
//
//   void _submit() {
//     if (!_formKey.currentState!.validate()) return;
//     _formKey.currentState!.save();
//
//     // Build title/note
//     String title = _label.trim().isNotEmpty ? _label.trim() : _kindLabel(_kind);
//     if (_kind == ReminderKind.medication) {
//       final parts = <String>[
//         if (_medName.trim().isNotEmpty) _medName.trim(),
//         if (_dosage.trim().isNotEmpty) _dosage.trim(),
//       ];
//       if (parts.isNotEmpty) title = parts.join(' — ');
//     }
//
//     // Compute schedule fields
//     List<int> weekdays = const [];
//     DateTime? oneDate;
//
//     switch (_repeat) {
//       case RepeatMode.once:
//       // normalize to date-only (time added by scheduler later)
//         oneDate = _oneDate == null
//             ? DateTime.now()
//             : DateTime(_oneDate!.year, _oneDate!.month, _oneDate!.day);
//         // prevent scheduling in the past for "once"
//         final candidate = _combineDateAndTime(oneDate!, _time);
//         if (candidate.isBefore(DateTime.now())) {
//           // push to next future minute to avoid a dead reminder (no UI change)
//           oneDate = DateTime.now().add(const Duration(days: 0));
//           oneDate = DateTime(oneDate!.year, oneDate!.month, oneDate!.day);
//         }
//         break;
//
//       case RepeatMode.daily:
//         weekdays = const [1, 2, 3, 4, 5, 6, 7];
//         break;
//
//       case RepeatMode.custom:
//         if (_weekdays.isEmpty) {
//           // require at least one day; non-visual guard (no layout change)
//           // You already have a form; simply return early.
//           return;
//         }
//         weekdays = _weekdays.toList()..sort();
//         break;
//     }
//
//     final reminder = Reminder(
//       id: _id(),
//       time: _time,
//       title: title,
//       note: _kindLabel(_kind),
//       weekdays: weekdays,
//       oneOffDate: oneDate,
//       enabled: true,
//     );
//     // Schedule notification
//     final when = _combineDateAndTime(oneDate ?? DateTime.now(), _time);
//     final id = int.parse(reminder.id.hashCode.toString().substring(0, 6));
//
//     await AndroidAlarmManager.oneShotAt(
//       when,
//       id,
//       showReminderNotification,
//       exact: true,
//       wakeup: true,
//       params: [id, title, _kindLabel(_kind)], // تمرير العنوان والنص
//     );
//
//     Navigator.pop(context, reminder);
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     final t = Theme.of(context);
//     final locale = context.locale.toLanguageTag();
//
//     return Scaffold(
//       appBar: AppBar(title: Text('add_reminder'.tr())),
//       body: Form(
//         key: _formKey,
//         child: ListView(
//           padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
//           children: [
//             // Label
//             Text('label'.tr(), style: t.textTheme.labelLarge),
//             SizedBox(height: 6.h),
//             TextFormField(
//               decoration: InputDecoration(hintText: 'label_hint'.tr()),
//               onSaved: (v) => _label = v?.trim() ?? '',
//             ),
//
//             SizedBox(height: 16.h),
//             Text('reminder_type'.tr(), style: t.textTheme.labelLarge),
//             SizedBox(height: 6.h),
//             DropdownButtonFormField<ReminderKind>(
//               value: _kind,
//               items: [
//                 DropdownMenuItem(value: ReminderKind.medication, child: Text('type_medication'.tr())),
//                 DropdownMenuItem(value: ReminderKind.wound, child: Text('type_wound'.tr())),
//                 DropdownMenuItem(value: ReminderKind.photo, child: Text('type_photo'.tr())),
//                 DropdownMenuItem(value: ReminderKind.other, child: Text('type_other'.tr())),
//               ],
//               onChanged: (v) => setState(() => _kind = v ?? _kind),
//             ),
//
//             if (_kind == ReminderKind.medication) ...[
//               SizedBox(height: 16.h),
//               Text('med_name'.tr(), style: t.textTheme.labelLarge),
//               SizedBox(height: 6.h),
//               TextFormField(
//                 decoration: InputDecoration(hintText: 'enter_medication'.tr()),
//                 onSaved: (v) => _medName = v?.trim() ?? '',
//               ),
//               SizedBox(height: 12.h),
//               Text('dosage'.tr(), style: t.textTheme.labelLarge),
//               SizedBox(height: 6.h),
//               TextFormField(
//                 decoration: InputDecoration(hintText: 'enter_dosage'.tr()),
//                 keyboardType: TextInputType.text,
//                 onSaved: (v) => _dosage = v?.trim() ?? '',
//               ),
//             ],
//
//             SizedBox(height: 16.h),
//             Text('repeat'.tr(), style: t.textTheme.labelLarge),
//             SizedBox(height: 6.h),
//             DropdownButtonFormField<RepeatMode>(
//               value: _repeat,
//               items: [
//                 DropdownMenuItem(value: RepeatMode.once, child: Text('repeat_once'.tr())),
//                 DropdownMenuItem(value: RepeatMode.daily, child: Text('repeat_daily'.tr())),
//                 DropdownMenuItem(value: RepeatMode.custom, child: Text('repeat_custom'.tr())),
//               ],
//               onChanged: (v) => setState(() => _repeat = v ?? _repeat),
//             ),
//
//             if (_repeat == RepeatMode.once) ...[
//               SizedBox(height: 16.h),
//               Text('day'.tr(), style: t.textTheme.labelLarge),
//               SizedBox(height: 6.h),
//               Row(
//                 children: [
//                   Expanded(
//                     child: Container(
//                       padding: EdgeInsets.all(12.w),
//                       decoration: BoxDecoration(
//                         color: t.colorScheme.surfaceVariant.withOpacity(.35),
//                         borderRadius: BorderRadius.circular(12.r),
//                       ),
//                       child: Text(
//                         _oneDate == null
//                             ? '—'
//                             : intl.DateFormat.yMMMMd(locale).format(_oneDate!),
//                         style: t.textTheme.bodyMedium,
//                       ),
//                     ),
//                   ),
//                   SizedBox(width: 8.w),
//                   FilledButton(onPressed: _pickDate, child: Text('pick'.tr())),
//                 ],
//               ),
//             ],
//
//             if (_repeat == RepeatMode.custom) ...[
//               SizedBox(height: 16.h),
//               Text('day'.tr(), style: t.textTheme.labelLarge),
//               SizedBox(height: 6.h),
//               Wrap(
//                 spacing: 8.w,
//                 runSpacing: 8.h,
//                 children: [
//                   for (final wd in const [1,2,3,4,5,6,7])
//                     FilterChip(
//                       label: Text('week_abbr.$wd'.tr()),
//                       selected: _weekdays.contains(wd),
//                       onSelected: (v) {
//                         setState(() {
//                           if (v) {
//                             _weekdays.add(wd);
//                           } else {
//                             _weekdays.remove(wd);
//                           }
//                         });
//                       },
//                     ),
//                 ],
//               ),
//             ],
//
//             SizedBox(height: 16.h),
//             Text('time'.tr(), style: t.textTheme.labelLarge),
//             SizedBox(height: 6.h),
//             Row(
//               children: [
//                 Expanded(
//                   child: Container(
//                     padding: EdgeInsets.all(12.w),
//                     decoration: BoxDecoration(
//                       color: t.colorScheme.surfaceVariant.withOpacity(.35),
//                       borderRadius: BorderRadius.circular(12.r),
//                     ),
//                     child: Text(_time.format(context), style: t.textTheme.bodyMedium),
//                   ),
//                 ),
//                 SizedBox(width: 8.w),
//                 FilledButton(onPressed: _pickTime, child: Text('pick'.tr())),
//               ],
//             ),
//
//             SizedBox(height: 24.h),
//             SizedBox(
//               height: 48.h,
//               child: FilledButton(
//                 onPressed: _submit,
//                 child: Text('apply'.tr(), style: TextStyle(fontSize: 16.sp)),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
import 'dart:io' show Platform;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;
import '../../../data/models/reminder.dart';
import '../../../data/repositories/reminders_repo.dart';
import '../../../core/services/notification_service.dart';

enum ReminderKind { medication, wound, photo, other }

enum RepeatMode { once, daily, custom }

class AddReminderScreen extends StatefulWidget {
  const AddReminderScreen({super.key});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();

  DateTime _combineDateAndTime(DateTime date, TimeOfDay t) =>
      DateTime(date.year, date.month, date.day, t.hour, t.minute);

  // fields
  String _label = '';
  ReminderKind _kind = ReminderKind.photo;
  RepeatMode _repeat = RepeatMode.once;

  // medication
  String _medName = '';
  String _dosage = '';

  // schedule
  DateTime? _oneDate = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  final Set<int> _weekdays = {DateTime.monday};

  String _id() => DateTime.now().millisecondsSinceEpoch.toString();

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _oneDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
      locale: context.locale,
    );
    if (picked != null) setState(() => _oneDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder:
          (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
            child: child!,
          ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  String _kindLabel(ReminderKind k) {
    switch (k) {
      case ReminderKind.medication:
        return 'type_medication'.tr();
      case ReminderKind.wound:
        return 'type_wound'.tr();
      case ReminderKind.photo:
        return 'type_photo'.tr();
      case ReminderKind.other:
        return 'type_other'.tr();
    }
  }

  // ✅ Full async submit - Uses RemindersRepo for proper scheduling
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    // Show loading indicator
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      // Title
      String title =
          _label.trim().isNotEmpty ? _label.trim() : _kindLabel(_kind);
      if (_kind == ReminderKind.medication) {
        final parts = <String>[
          if (_medName.trim().isNotEmpty) _medName.trim(),
          if (_dosage.trim().isNotEmpty) _dosage.trim(),
        ];
        if (parts.isNotEmpty) title = parts.join(' — ');
      }

      // Schedule config
      List<int> weekdays = const [];
      DateTime? oneDate;

      switch (_repeat) {
        case RepeatMode.once:
          oneDate =
              _oneDate == null
                  ? DateTime.now()
                  : DateTime(_oneDate!.year, _oneDate!.month, _oneDate!.day);
          final candidate = _combineDateAndTime(oneDate, _time);
          if (candidate.isBefore(DateTime.now())) {
            final nextMinute = DateTime.now().add(const Duration(minutes: 1));
            oneDate = DateTime(
              nextMinute.year,
              nextMinute.month,
              nextMinute.day,
            );
          }
          break;
        case RepeatMode.daily:
          weekdays = const [1, 2, 3, 4, 5, 6, 7];
          break;
        case RepeatMode.custom:
          if (_weekdays.isEmpty) {
            if (mounted) {
              Navigator.pop(context); // Close loading
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Please select at least one day'.tr())),
              );
            }
            return;
          }
          weekdays = _weekdays.toList()..sort();
          break;
      }

      final reminder = Reminder(
        id: _id(),
        time: _time,
        title: title,
        note: _kindLabel(_kind),
        weekdays: weekdays,
        oneOffDate: oneDate,
        enabled: true,
      );

      // 🔔 Check notification permissions first
      final notifService = NotificationService.I;
      final hasPermission = await notifService.areNotificationsEnabled();

      if (!hasPermission && !kIsWeb && Platform.isAndroid) {
        // Try to request permission again
        final granted = await notifService.requestNotificationPermission();
        if (!granted) {
          if (mounted) {
            Navigator.pop(context); // Close loading
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  '⚠️ Notification permission is required for reminders. Please enable it in Settings.',
                ),
                duration: const Duration(seconds: 5),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      // 🔔 Schedule notification using RemindersRepo
      final repo = RemindersRepo();

      // For testing: if reminder is less than 10 seconds away, show immediate test notification
      final when = _combineDateAndTime(oneDate ?? DateTime.now(), _time);
      final timeUntil = when.difference(DateTime.now());
      if (timeUntil.inSeconds <= 10 && timeUntil.inSeconds > 0) {
        debugPrint(
          '🧪 Test notification will fire in ${timeUntil.inSeconds} seconds',
        );
      }

      await repo.schedule(reminder);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success message
      if (mounted) {
        final when = _combineDateAndTime(oneDate ?? DateTime.now(), _time);
        final localeStr = context.locale.toLanguageTag();
        String message;
        if (_repeat == RepeatMode.daily) {
          message = '⏰ Daily reminder scheduled for ${_time.format(context)}';
        } else if (_repeat == RepeatMode.once) {
          message =
              '⏰ Reminder scheduled for ${intl.DateFormat.yMd(localeStr).add_jm().format(when)}';
        } else {
          message =
              '⏰ Reminder scheduled for selected days at ${_time.format(context)}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Return reminder to parent screen
      if (mounted) {
        Navigator.pop(context, reminder);
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scheduling reminder: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final locale = context.locale.toLanguageTag();

    return Scaffold(
      appBar: AppBar(title: Text('add_reminder'.tr())),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
          children: [
            Text('label'.tr(), style: t.textTheme.labelLarge),
            SizedBox(height: 6.h),
            TextFormField(
              decoration: InputDecoration(hintText: 'label_hint'.tr()),
              onSaved: (v) => _label = v?.trim() ?? '',
            ),

            SizedBox(height: 16.h),
            Text('reminder_type'.tr(), style: t.textTheme.labelLarge),
            SizedBox(height: 6.h),
            DropdownButtonFormField<ReminderKind>(
              value: _kind,
              items: [
                DropdownMenuItem(
                  value: ReminderKind.medication,
                  child: Text('type_medication'.tr()),
                ),
                DropdownMenuItem(
                  value: ReminderKind.wound,
                  child: Text('type_wound'.tr()),
                ),
                DropdownMenuItem(
                  value: ReminderKind.photo,
                  child: Text('type_photo'.tr()),
                ),
                DropdownMenuItem(
                  value: ReminderKind.other,
                  child: Text('type_other'.tr()),
                ),
              ],
              onChanged: (v) => setState(() => _kind = v ?? _kind),
            ),

            if (_kind == ReminderKind.medication) ...[
              SizedBox(height: 16.h),
              Text('med_name'.tr(), style: t.textTheme.labelLarge),
              SizedBox(height: 6.h),
              TextFormField(
                decoration: InputDecoration(hintText: 'enter_medication'.tr()),
                onSaved: (v) => _medName = v?.trim() ?? '',
              ),
              SizedBox(height: 12.h),
              Text('dosage'.tr(), style: t.textTheme.labelLarge),
              SizedBox(height: 6.h),
              TextFormField(
                decoration: InputDecoration(hintText: 'enter_dosage'.tr()),
                keyboardType: TextInputType.text,
                onSaved: (v) => _dosage = v?.trim() ?? '',
              ),
            ],

            SizedBox(height: 16.h),
            Text('repeat'.tr(), style: t.textTheme.labelLarge),
            SizedBox(height: 6.h),
            DropdownButtonFormField<RepeatMode>(
              value: _repeat,
              items: [
                DropdownMenuItem(
                  value: RepeatMode.once,
                  child: Text('repeat_once'.tr()),
                ),
                DropdownMenuItem(
                  value: RepeatMode.daily,
                  child: Text('repeat_daily'.tr()),
                ),
                DropdownMenuItem(
                  value: RepeatMode.custom,
                  child: Text('repeat_custom'.tr()),
                ),
              ],
              onChanged: (v) => setState(() => _repeat = v ?? _repeat),
            ),

            if (_repeat == RepeatMode.once) ...[
              SizedBox(height: 16.h),
              Text('day'.tr(), style: t.textTheme.labelLarge),
              SizedBox(height: 6.h),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: t.colorScheme.surfaceVariant.withOpacity(.35),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        _oneDate == null
                            ? '—'
                            : intl.DateFormat.yMMMMd(locale).format(_oneDate!),
                        style: t.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  FilledButton(onPressed: _pickDate, child: Text('pick'.tr())),
                ],
              ),
            ],

            if (_repeat == RepeatMode.custom) ...[
              SizedBox(height: 16.h),
              Text('day'.tr(), style: t.textTheme.labelLarge),
              SizedBox(height: 6.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  for (final wd in const [1, 2, 3, 4, 5, 6, 7])
                    FilterChip(
                      label: Text('week_abbr.$wd'.tr()),
                      selected: _weekdays.contains(wd),
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _weekdays.add(wd);
                          } else {
                            _weekdays.remove(wd);
                          }
                        });
                      },
                    ),
                ],
              ),
            ],

            SizedBox(height: 16.h),
            Text('time'.tr(), style: t.textTheme.labelLarge),
            SizedBox(height: 6.h),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: t.colorScheme.surfaceVariant.withOpacity(.35),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      _time.format(context),
                      style: t.textTheme.bodyMedium,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                FilledButton(onPressed: _pickTime, child: Text('pick'.tr())),
              ],
            ),

            SizedBox(height: 24.h),
            SizedBox(
              height: 48.h,
              child: FilledButton(
                onPressed: _submit,
                child: Text('apply'.tr(), style: TextStyle(fontSize: 16.sp)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
