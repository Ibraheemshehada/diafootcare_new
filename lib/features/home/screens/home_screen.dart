import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../../notes/viewmodel/notes_viewmodel.dart';
import '../../glucose/viewmodel/glucose_viewmodel.dart';
import '../../glucose/screens/glucose_screen.dart' show glucoseStatusColor, glucoseStatusLabel;
import '../../selfcare/viewmodel/self_care_viewmodel.dart';
import '../../appointments/viewmodel/appointments_viewmodel.dart';
import '../viewmodel/home_viewmodel.dart';
import '../widgets/home_header.dart';
import '../widgets/whats_new_card.dart';
import '../widgets/self_care_tip_card.dart';
import '../widgets/recent_note_card.dart';
import '../widgets/service_tile.dart';
import '../../../routes/app_routes.dart';

// ✅ import the notes state

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HomeViewModel(),
      child: Consumer2<HomeViewModel, NotesViewModel>(
        builder: (context, vm, notesVm, _) {
          final t = Theme.of(context);

          // ✅ pull recent notes from NotesViewModel (shared source of truth)
          final recent = notesVm.recent(count: 10);

          // Latest glucose reading for the dashboard card
          final glucoseVm = context.watch<GlucoseViewModel>();
          final latestGlucose = glucoseVm.latest;

          // Self-care summary (rotating tip + today's progress + streak)
          final selfCareVm = context.watch<SelfCareViewModel>();
          final selfCareTip = selfCareVm.tip;

          // Latest DFU risk for the dashboard (null = no wound analysis yet)
          final dfu = _dfuStatus(vm.dfuBadge);

          // Next upcoming appointment for the hero row
          final nextAppt = context.watch<AppointmentsViewModel>().nextUpcoming;
          final locale = context.locale.toLanguageTag();
          final nextApptText = nextAppt == null
              ? null
              : '${nextAppt.title} · ${intl.DateFormat.MMMd(locale).add_jm().format(nextAppt.dateTime)}';

          // Pastel palettes for light/dark
          final colorsLight = <Color>[
            const Color(0xFFFFF1E6),
            const Color(0xFFFCE8F4),
            const Color(0xFFE7EEFF),
            const Color(0xFFE8F5EE),
            const Color(0xFFF9E7FF),
          ];
          final colorsDark = <Color>[
            const Color(0xFF3B2E2A),
            const Color(0xFF2A3142),
            const Color(0xFF26342C),
            const Color(0xFF352A3C),
            const Color(0xFF2C2F35),
          ];
          final palette =
              t.brightness == Brightness.dark ? colorsDark : colorsLight;

          return Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    HomeHeader(
                      userFirstName: vm.userFirstName,
                      onNotifications: () {
                        Navigator.pushNamed(context, AppRoutes.notifications);
                      },
                    ),

                    // What's new
                    WhatsNewCard(
                      nextReminder: vm.nextReminder,
                      nextReminderTitle: vm.nextReminderTitle,
                      weeklyProgressPercent: vm.weeklyProgressPercent,
                      latestGlucoseText: latestGlucose == null
                          ? null
                          : '${latestGlucose.value.toStringAsFixed(0)} mg/dL',
                      latestGlucoseStatus: latestGlucose == null
                          ? null
                          : glucoseStatusLabel(latestGlucose.status),
                      latestGlucoseColor: latestGlucose == null
                          ? null
                          : glucoseStatusColor(latestGlucose.status),
                      onGlucoseTap: () =>
                          Navigator.pushNamed(context, AppRoutes.glucose),
                      dfuStatusLabel: dfu?.label,
                      dfuStatusIcon: dfu?.icon,
                      dfuStatusColor: dfu?.color,
                      onDfuTap: () =>
                          Navigator.pushNamed(context, AppRoutes.measure),
                      nextAppointmentText: nextApptText,
                      onAppointmentTap: () =>
                          Navigator.pushNamed(context, AppRoutes.appointments),
                    ),

                    // Self-care summary + rotating tip → opens the Self-Care screen
                    if (selfCareTip != null)
                      SelfCareTipCard(
                        tip: selfCareTip,
                        doneToday: selfCareVm.doneToday,
                        totalTasks: selfCareVm.totalTasks,
                        streak: selfCareVm.streak,
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.selfCare),
                      ),

                    // Recent notes section title
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
                      child: Text(
                        "recent_notes".tr(),
                        style: t.textTheme.titleMedium,
                      ),
                    ),

                    // Recent notes horizontal list (synced with Notes feature)
                    SizedBox(
                      height: 160.h,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.only(left: 16.w),
                        itemCount: recent.length,
                        itemBuilder: (context, i) {
                          final color = palette[i % palette.length];
                          return RecentNoteCard(note: recent[i], color: color);
                        },
                      ),
                    ),

                    // Services title
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
                      child: Text(
                        "services".tr(),
                        style: t.textTheme.titleMedium,
                      ),
                    ),

                    // Services grid (2x2)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: vm.services.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12.h,
                          crossAxisSpacing: 12.w,
                          childAspectRatio: 1.1,
                        ),
                        itemBuilder: (context, i) {
                          final s = vm.services[i];
                          return ServiceTile(
                            item: s,
                            onTap: () => Navigator.pushNamed(context, s.route),
                          );
                        },
                      ),
                    ),

                    SizedBox(height: 24.h),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Localized DFU risk presentation (label + color + icon), mapped from the
/// English badge key. Mirrors the AI result screen's risk banner so Home and
/// the analysis screen agree on colors/wording.
class _DfuStatus {
  final String label;
  final Color color;
  final IconData icon;
  const _DfuStatus(this.label, this.color, this.icon);
}

_DfuStatus? _dfuStatus(String? badge) {
  switch (badge) {
    case null:
      return null;
    case 'High Risk':
      return _DfuStatus('badge_high_risk'.tr(), const Color(0xFFD64545),
          Icons.warning_amber_rounded);
    case 'Infection Detected':
      return _DfuStatus('badge_infection'.tr(), const Color(0xFFE8A317),
          Icons.coronavirus_outlined);
    case 'Impaired Blood Flow':
      return _DfuStatus('badge_ischaemia'.tr(), const Color(0xFFE8A317),
          Icons.bloodtype_outlined);
    default: // Normal
      return _DfuStatus('badge_normal'.tr(), const Color(0xFF2E9E6B),
          Icons.check_circle_outline);
  }
}
