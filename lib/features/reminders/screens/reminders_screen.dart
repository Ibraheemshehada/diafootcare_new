import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../data/models/reminder.dart';
import '../viewmodel/reminders_viewmodel.dart';
import '../widgets/day_chip.dart';
import '../widgets/reminder_tile.dart';
import 'package:intl/intl.dart';

import 'add_reminder_screen.dart'; // ✅
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  DateTime _startOfWeek(DateTime anchor) {
    // Monday as start of week
    final diff = anchor.weekday - DateTime.monday; // 0..6
    final d = anchor.subtract(Duration(days: diff));
    return DateTime(d.year, d.month, d.day);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final vm = context.watch<RemindersViewModel>();

    final start = _startOfWeek(vm.selectedDay);
    final week = List.generate(7, (i) => start.add(Duration(days: i)));

    return Scaffold(
      appBar: AppBar(title: Text('daily_reminders'.tr(), style: TextStyle(fontSize: 18.sp)),backgroundColor: t.scaffoldBackgroundColor,),
      floatingActionButton:FloatingActionButton(
        onPressed: () async {
          final r = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddReminderScreen()),
          );
          if (r != null && r is Reminder) {
            context.read<RemindersViewModel>().add(r);
          }
        },
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Tagline
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
            child: Text('care_plan_hint'.tr(), style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.primary)),
          ),

          // Week strip
          SizedBox(height: 12.h),
          SizedBox(
            height: 80.h,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, i) {
                final d = week[i];
                return DayChip(
                  date: d,
                  selected: d.year == vm.selectedDay.year && d.month == vm.selectedDay.month && d.day == vm.selectedDay.day,
                  onTap: () => vm.selectDay(d),
                );
              },
              separatorBuilder: (_, __) => SizedBox(width: 8.w),
              itemCount: week.length,
            ),
          ),

          // Progress bubble
          SizedBox(height: 12.h),
          _ProgressBubble(
            done: vm.enabledForSelectedDay(),
            total: vm.totalForSelectedDay(),
            day: vm.selectedDay, // pass selected day down
          ),
          // Reminders list
          ...vm.remindersForSelectedDay().map((r) => ReminderTile(
            r: r,
            onDelete: () => vm.remove(r.id),
            onToggle: (v) => vm.toggle(r.id, v),
          )),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }
}

class _ProgressBubble extends StatelessWidget {
  final int done, total;
  final DateTime day; // ✅ add this
  const _ProgressBubble({required this.done, required this.total, required this.day});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final locale = context.locale.toLanguageTag();
    final dayName = DateFormat('EEEE', locale).format(day); // ✅ selected day label

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: t.colorScheme.primary.withOpacity(.06),
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.alarm_rounded, color: Colors.amber.shade600, size: 36.sp),
            SizedBox(height: 8.h),
            // ✅ shows enabled/total e.g., 1/2
            Text('$done/$total',
                style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            SizedBox(height: 6.h),
            Text(dayName, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}