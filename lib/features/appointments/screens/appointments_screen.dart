import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../../../data/models/appointment.dart';
import '../viewmodel/appointments_viewmodel.dart';
import 'add_appointment_screen.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final vm = context.watch<AppointmentsViewModel>();
    final locale = context.locale.toLanguageTag();
    final upcoming = vm.upcoming;
    final past = vm.past;

    return Scaffold(
      appBar: AppBar(
        title: Text('appt_title'.tr(), style: TextStyle(fontSize: 18.sp)),
        backgroundColor: t.scaffoldBackgroundColor,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddAppointmentScreen()),
        ),
        icon: const Icon(Icons.add),
        label: Text('appt_add'.tr()),
      ),
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : (upcoming.isEmpty && past.isEmpty)
              ? _EmptyState()
              : ListView(
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 90.h),
                  children: [
                    if (upcoming.isNotEmpty) ...[
                      _SectionTitle('appt_upcoming'.tr()),
                      ...upcoming.map((a) => _AppointmentTile(
                            key: ValueKey(a.id),
                            appt: a,
                            locale: locale,
                            onDelete: () => vm.remove(a.id),
                          )),
                    ],
                    if (past.isNotEmpty) ...[
                      SizedBox(height: 8.h),
                      _SectionTitle('appt_past'.tr()),
                      ...past.map((a) => _AppointmentTile(
                            key: ValueKey(a.id),
                            appt: a,
                            locale: locale,
                            isPast: true,
                            onDelete: () => vm.remove(a.id),
                          )),
                    ],
                  ],
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available_outlined,
                size: 64.sp, color: t.hintColor),
            SizedBox(height: 16.h),
            Text('appt_empty'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(color: t.hintColor, fontSize: 14.sp)),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h, top: 4.h),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  final Appointment appt;
  final String locale;
  final bool isPast;
  final VoidCallback onDelete;
  const _AppointmentTile({
    super.key,
    required this.appt,
    required this.locale,
    this.isPast = false,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final primary = t.colorScheme.primary;
    final blockColor = isPast ? t.hintColor : primary;
    final dayNum = intl.DateFormat.d(locale).format(appt.dateTime);
    final monthAbbr = intl.DateFormat.MMM(locale).format(appt.dateTime);
    final timeStr = intl.DateFormat.jm(locale).format(appt.dateTime);

    return Dismissible(
      key: ValueKey('appt_dismiss_${appt.id}'),
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
      child: Opacity(
        opacity: isPast ? .6 : 1,
        child: Container(
          margin: EdgeInsets.only(bottom: 10.h),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: t.cardColor,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: t.dividerColor.withValues(alpha: .3)),
          ),
          child: Row(
            children: [
              // Date block
              Container(
                width: 52.w,
                padding: EdgeInsets.symmetric(vertical: 8.h),
                decoration: BoxDecoration(
                  color: blockColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(dayNum,
                        style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800,
                            color: blockColor)),
                    Text(monthAbbr.toUpperCase(),
                        style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: blockColor)),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              // Details
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(appt.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15.sp, fontWeight: FontWeight.w700)),
                    SizedBox(height: 3.h),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 13.sp, color: t.hintColor),
                        SizedBox(width: 4.w),
                        Text(timeStr,
                            style: TextStyle(
                                fontSize: 12.sp, color: t.hintColor)),
                        if (appt.location.trim().isNotEmpty) ...[
                          SizedBox(width: 10.w),
                          Icon(Icons.place_outlined,
                              size: 13.sp, color: t.hintColor),
                          SizedBox(width: 4.w),
                          Flexible(
                            child: Text(appt.location.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12.sp, color: t.hintColor)),
                          ),
                        ],
                      ],
                    ),
                    if (!isPast && appt.reminderLead >= 0) ...[
                      SizedBox(height: 6.h),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_active_outlined,
                              size: 13.sp, color: primary),
                          SizedBox(width: 4.w),
                          Text(appointmentLeadKey(appt.reminderLead).tr(),
                              style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: primary)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
