import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../data/models/sus_entry.dart';
import '../viewmodel/wellbeing_viewmodel.dart';

/// The 10-item System Usability Scale (Brooke, 1986).
/// Statements are shown verbatim (localized) to preserve instrument validity.
class SusSurveyScreen extends StatefulWidget {
  const SusSurveyScreen({super.key});

  @override
  State<SusSurveyScreen> createState() => _SusSurveyScreenState();
}

class _SusSurveyScreenState extends State<SusSurveyScreen> {
  /// 0 = unanswered, otherwise 1..5.
  final List<int> _answers = List<int>.filled(susItemCount, 0);

  /// Participant declaration must be acknowledged before the response counts.
  bool _consented = false;

  bool get _complete => !_answers.contains(0);
  int get _answeredCount => _answers.where((a) => a > 0).length;

  Future<void> _submit() async {
    if (!_consented) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('sus_consent_required'.tr())),
      );
      return;
    }
    if (!_complete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('sus_incomplete'.tr(
              namedArgs: {'answered': '$_answeredCount', 'total': '$susItemCount'})),
        ),
      );
      return;
    }
    final score = await context.read<WellbeingViewModel>().addSus(_answers);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _SusResultDialog(score: score),
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('sus_title'.tr())),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
        children: [
          Text('sus_intro'.tr(),
              style: TextStyle(fontSize: 13.sp, color: t.hintColor)),
          SizedBox(height: 12.h),
          _DeclarationCard(
            consented: _consented,
            onChanged: (v) => setState(() => _consented = v),
          ),
          SizedBox(height: 12.h),
          const _ScaleLegend(),
          SizedBox(height: 16.h),
          ...List.generate(susItemCount, (i) {
            return _SusItem(
              number: i + 1,
              statement: susItemKey(i).tr(),
              value: _answers[i],
              onChanged: (v) => setState(() => _answers[i] = v),
            );
          }),
          SizedBox(height: 8.h),
          Text(
            'sus_progress'.tr(namedArgs: {
              'answered': '$_answeredCount',
              'total': '$susItemCount',
            }),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.sp, color: t.hintColor),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 52.h,
            child: FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check),
              label:
                  Text('sus_submit'.tr(), style: TextStyle(fontSize: 16.sp)),
            ),
          ),
          SizedBox(height: 16.h),
          // Attribution required when reproducing the SUS instrument.
          Text('sus_copyright'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.sp, color: t.hintColor)),
        ],
      ),
    );
  }
}

/// Participant declaration shown before the questionnaire. The response is only
/// recorded once the participant acknowledges it (research consent).
class _DeclarationCard extends StatelessWidget {
  final bool consented;
  final ValueChanged<bool> onChanged;
  const _DeclarationCard({required this.consented, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final primary = t.colorScheme.primary;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: primary.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_outlined, size: 20.sp, color: primary),
              SizedBox(width: 8.w),
              Expanded(
                child: Text('sus_declaration_title'.tr(),
                    style: TextStyle(
                        fontSize: 14.sp, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text('sus_declaration_body'.tr(),
              style: TextStyle(
                  fontSize: 12.5.sp, height: 1.45, color: t.hintColor)),
          SizedBox(height: 6.h),
          // Whole row is one large, screen-reader friendly tap target.
          Semantics(
            checked: consented,
            label: 'sus_consent_label'.tr(),
            child: InkWell(
              onTap: () => onChanged(!consented),
              borderRadius: BorderRadius.circular(10.r),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 6.h),
                child: Row(
                  children: [
                    Checkbox(
                      value: consented,
                      onChanged: (v) => onChanged(v ?? false),
                      activeColor: primary,
                    ),
                    Expanded(
                      child: Text('sus_consent_label'.tr(),
                          style: TextStyle(
                              fontSize: 13.sp, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScaleLegend extends StatelessWidget {
  const _ScaleLegend();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: t.colorScheme.primary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text('sus_anchor_low'.tr(),
                style: TextStyle(fontSize: 12.sp, color: t.hintColor)),
          ),
          SizedBox(width: 8.w),
          Flexible(
            child: Text('sus_anchor_high'.tr(),
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 12.sp, color: t.hintColor)),
          ),
        ],
      ),
    );
  }
}

class _SusItem extends StatelessWidget {
  final int number;
  final String statement;
  final int value; // 0 = unanswered
  final ValueChanged<int> onChanged;
  const _SusItem({
    required this.number,
    required this.statement,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final primary = t.colorScheme.primary;
    final answered = value > 0;
    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: answered ? primary.withValues(alpha: .05) : t.cardColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: answered
              ? primary.withValues(alpha: .35)
              : t.dividerColor.withValues(alpha: .35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$number. $statement',
              style: TextStyle(
                  fontSize: 14.sp,
                  height: 1.35,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (i) {
              final n = i + 1;
              final selected = value == n;
              return Semantics(
                label: '$n',
                selected: selected,
                button: true,
                child: InkResponse(
                  onTap: () => onChanged(n),
                  radius: 28.r,
                  child: Container(
                    width: 48.w,
                    height: 48.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          selected ? primary : primary.withValues(alpha: .07),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? primary
                            : t.dividerColor.withValues(alpha: .6),
                      ),
                    ),
                    child: Text('$n',
                        style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : primary)),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _SusResultDialog extends StatelessWidget {
  final double score;
  const _SusResultDialog({required this.score});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final band = susAdjectiveKey(score).tr();
    final color = score >= 68
        ? Colors.green.shade600
        : (score >= 51 ? Colors.amber.shade700 : Colors.red.shade600);
    return AlertDialog(
      title: Text('sus_result_title'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(score.toStringAsFixed(1),
              style: TextStyle(
                  fontSize: 40.sp,
                  fontWeight: FontWeight.w800,
                  color: color)),
          Text('sus_out_of'.tr(),
              style: TextStyle(fontSize: 12.sp, color: t.hintColor)),
          SizedBox(height: 10.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(band,
                style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ),
          SizedBox(height: 12.h),
          Text('sus_benchmark_note'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.sp, color: t.hintColor)),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text('ok'.tr()),
        ),
      ],
    );
  }
}
