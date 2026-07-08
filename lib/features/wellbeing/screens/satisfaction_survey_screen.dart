import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../viewmodel/wellbeing_viewmodel.dart';

class SatisfactionSurveyScreen extends StatefulWidget {
  const SatisfactionSurveyScreen({super.key});

  @override
  State<SatisfactionSurveyScreen> createState() =>
      _SatisfactionSurveyScreenState();
}

class _SatisfactionSurveyScreenState extends State<SatisfactionSurveyScreen> {
  int _ease = 0;
  int _usefulness = 0;
  int _willingness = 0;

  bool get _complete => _ease > 0 && _usefulness > 0 && _willingness > 0;

  @override
  void initState() {
    super.initState();
    AnalyticsService.I.logTaskStart('satisfaction_survey');
  }

  Future<void> _save() async {
    if (!_complete) {
      await showAppError(context, 'satisfaction_incomplete'.tr());
      return;
    }
    try {
      await context.read<WellbeingViewModel>().addSatisfaction(
            ease: _ease,
            usefulness: _usefulness,
            willingness: _willingness,
          );
    } catch (e) {
      if (!mounted) return;
      await showAppError(context, 'dialog_save_failed'.tr(),
          technicalDetail: e);
      return;
    }
    AnalyticsService.I.logTaskComplete('satisfaction_survey');
    if (!mounted) return;
    await showAppSuccess(context, 'satisfaction_saved'.tr());
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('satisfaction_title'.tr())),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
        children: [
          Text('satisfaction_intro'.tr(),
              style: TextStyle(fontSize: 13.sp, color: t.hintColor)),
          SizedBox(height: 20.h),
          _LikertItem(
            statement: 'satisfaction_ease'.tr(),
            value: _ease,
            onChanged: (v) => setState(() => _ease = v),
          ),
          _LikertItem(
            statement: 'satisfaction_usefulness'.tr(),
            value: _usefulness,
            onChanged: (v) => setState(() => _usefulness = v),
          ),
          _LikertItem(
            statement: 'satisfaction_willingness'.tr(),
            value: _willingness,
            onChanged: (v) => setState(() => _willingness = v),
          ),
          SizedBox(height: 20.h),
          FilledButton.icon(
            onPressed: _save,
            style: FilledButton.styleFrom(
                minimumSize: Size(double.infinity, 50.h)),
            icon: const Icon(Icons.check),
            label: Text('satisfaction_submit'.tr(),
                style: TextStyle(fontSize: 16.sp)),
          ),
        ],
      ),
    );
  }
}

class _LikertItem extends StatelessWidget {
  final String statement;
  final int value; // 0 = unanswered, 1..5
  final ValueChanged<int> onChanged;
  const _LikertItem({
    required this.statement,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final primary = t.colorScheme.primary;
    return Padding(
      padding: EdgeInsets.only(bottom: 22.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(statement,
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700)),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (i) {
              final n = i + 1;
              final selected = value == n;
              return GestureDetector(
                onTap: () => onChanged(n),
                child: Container(
                  width: 46.w,
                  height: 46.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? primary
                        : primary.withValues(alpha: .08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? primary
                          : t.dividerColor.withValues(alpha: .5),
                    ),
                  ),
                  child: Text('$n',
                      style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : primary)),
                ),
              );
            }),
          ),
          SizedBox(height: 6.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('satisfaction_disagree'.tr(),
                  style: TextStyle(fontSize: 12.sp, color: t.hintColor)),
              Text('satisfaction_agree'.tr(),
                  style: TextStyle(fontSize: 12.sp, color: t.hintColor)),
            ],
          ),
        ],
      ),
    );
  }
}
