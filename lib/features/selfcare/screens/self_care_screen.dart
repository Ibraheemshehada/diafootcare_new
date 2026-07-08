import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../data/models/self_care_task.dart';
import '../viewmodel/self_care_viewmodel.dart';

/// Icon shown for each self-care task, keyed by the task's stable key.
IconData selfCareTaskIcon(String key) {
  switch (key) {
    case 'foot_inspection':
      return Icons.visibility_outlined;
    case 'wash_dry':
      return Icons.wash_outlined;
    case 'moisturize':
      return Icons.spa_outlined;
    case 'footwear':
      return Icons.directions_walk;
    case 'wound_check':
      return Icons.healing_outlined;
    default:
      return Icons.check_circle_outline;
  }
}

class SelfCareScreen extends StatelessWidget {
  const SelfCareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final vm = context.watch<SelfCareViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text('selfcare_title'.tr(), style: TextStyle(fontSize: 18.sp)),
        backgroundColor: t.scaffoldBackgroundColor,
      ),
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
              children: [
                _SummaryCard(vm: vm),
                SizedBox(height: 16.h),
                Text('selfcare_checklist'.tr(),
                    style: t.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                SizedBox(height: 4.h),
                Text('selfcare_checklist_hint'.tr(),
                    style: TextStyle(fontSize: 12.sp, color: t.hintColor)),
                SizedBox(height: 12.h),
                ...vm.tasks.map((key) => _TaskTile(
                      key: ValueKey(key),
                      taskKey: key,
                      done: vm.isDone(key),
                      onToggle: () => vm.toggle(key),
                    )),
                SizedBox(height: 20.h),
                if (vm.tip != null)
                  _TipCard(tip: vm.tip!, onShuffle: vm.shuffleTip),
                SizedBox(height: 4.h),
                Theme(
                  // Hide the ExpansionTile's default divider lines.
                  data: t.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    title: Text('selfcare_advice_title'.tr(),
                        style: t.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    children: [
                      _AdviceCard(
                        title: 'selfcare_do_title'.tr(),
                        icon: Icons.check_circle,
                        color: Colors.green.shade600,
                        itemKeys: selfCareDoKeys,
                      ),
                      _AdviceCard(
                        title: 'selfcare_dont_title'.tr(),
                        icon: Icons.cancel,
                        color: Colors.red.shade600,
                        itemKeys: selfCareDontKeys,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// A single rotating foot-care tip (a random "Do" or "Don't"), with a shuffle
/// button to draw another. The tip itself is chosen in the view model so it
/// stays stable while the screen rebuilds.
class _TipCard extends StatelessWidget {
  final SelfCareTip tip;
  final VoidCallback onShuffle;
  const _TipCard({required this.tip, required this.onShuffle});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDo = tip.isDo;
    final color = isDo ? Colors.green.shade600 : Colors.red.shade600;
    final badgeIcon = isDo ? Icons.check_circle : Icons.cancel;
    final badgeLabel =
        isDo ? 'selfcare_do_title'.tr() : 'selfcare_dont_title'.tr();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: t.colorScheme.primary.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: t.colorScheme.primary.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  color: t.colorScheme.primary, size: 20.sp),
              SizedBox(width: 8.w),
              Text('selfcare_tip_label'.tr(),
                  style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: t.colorScheme.primary)),
              const Spacer(),
              TextButton.icon(
                onPressed: onShuffle,
                icon: Icon(Icons.refresh, size: 18.sp),
                label: Text('selfcare_tip_next'.tr(),
                    style: TextStyle(
                        fontSize: 12.sp, fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  foregroundColor: t.colorScheme.primary,
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  minimumSize: Size(0, 40.h),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 14.sp, color: color),
                    SizedBox(width: 4.w),
                    Text(badgeLabel,
                        style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: color)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            tip.messageKey.tr(),
            style: TextStyle(
                fontSize: 14.sp, height: 1.45, color: t.colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}

class _AdviceCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> itemKeys;
  const _AdviceCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.itemKeys,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22.sp),
              SizedBox(width: 8.w),
              Text(title,
                  style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ],
          ),
          SizedBox(height: 12.h),
          ...itemKeys.map((k) => Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 6.h),
                      child: Container(
                        width: 6.w,
                        height: 6.w,
                        decoration:
                            BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        k.tr(),
                        style: TextStyle(
                          fontSize: 13.sp,
                          height: 1.45,
                          color: t.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final SelfCareViewModel vm;
  const _SummaryCard({required this.vm});

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
                    style:
                        TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('selfcare_today'.tr(),
                    style:
                        TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700)),
                SizedBox(height: 4.h),
                Text(
                  'selfcare_done_count'.tr(namedArgs: {
                    'done': vm.doneToday.toString(),
                    'total': vm.totalTasks.toString(),
                  }),
                  style: TextStyle(fontSize: 12.sp, color: t.hintColor),
                ),
                if (vm.streak > 0) ...[
                  SizedBox(height: 8.h),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department,
                            size: 16.sp, color: Colors.deepOrange),
                        SizedBox(width: 4.w),
                        Text(
                          'selfcare_streak'.tr(
                              namedArgs: {'days': vm.streak.toString()}),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final String taskKey;
  final bool done;
  final VoidCallback onToggle;
  const _TaskTile({
    super.key,
    required this.taskKey,
    required this.done,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final primary = t.colorScheme.primary;
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(14.r),
          child: Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: done
                  ? primary.withValues(alpha: .06)
                  : t.cardColor,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: done
                    ? primary.withValues(alpha: .5)
                    : t.dividerColor.withValues(alpha: .3),
              ),
            ),
            child: Row(
              children: [
                Icon(selfCareTaskIcon(taskKey), color: primary, size: 24.sp),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('selfcare_task_$taskKey'.tr(),
                          style: TextStyle(
                              fontSize: 15.sp, fontWeight: FontWeight.w700)),
                      SizedBox(height: 2.h),
                      Text('selfcare_task_${taskKey}_desc'.tr(),
                          style:
                              TextStyle(fontSize: 12.sp, color: t.hintColor)),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: done ? primary : t.dividerColor,
                  size: 26.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
