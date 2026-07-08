import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../viewmodel/wellbeing_viewmodel.dart';
import 'wellbeing_screen.dart' show qolScoreColor;

class QolCheckInScreen extends StatefulWidget {
  const QolCheckInScreen({super.key});

  @override
  State<QolCheckInScreen> createState() => _QolCheckInScreenState();
}

class _QolCheckInScreenState extends State<QolCheckInScreen> {
  double _pain = 0;
  double _mobility = 0;
  double _emotional = 0;

  @override
  void initState() {
    super.initState();
    AnalyticsService.I.logTaskStart('qol_checkin');
  }

  Future<void> _save() async {
    try {
      await context.read<WellbeingViewModel>().addQol(
            pain: _pain.round(),
            mobility: _mobility.round(),
            emotional: _emotional.round(),
          );
    } catch (e) {
      if (!mounted) return;
      await showAppError(context, 'dialog_save_failed'.tr(),
          technicalDetail: e);
      return;
    }
    AnalyticsService.I.logTaskComplete('qol_checkin');
    if (!mounted) return;
    await showAppSuccess(context, 'wellbeing_saved'.tr());
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('wellbeing_new_checkin'.tr())),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
        children: [
          Text('qol_intro'.tr(),
              style: TextStyle(fontSize: 13.sp, color: t.hintColor)),
          SizedBox(height: 16.h),
          _ScaleSlider(
            label: 'qol_pain'.tr(),
            hint: 'qol_pain_hint'.tr(),
            value: _pain,
            onChanged: (v) => setState(() => _pain = v),
          ),
          _ScaleSlider(
            label: 'qol_mobility'.tr(),
            hint: 'qol_mobility_hint'.tr(),
            value: _mobility,
            onChanged: (v) => setState(() => _mobility = v),
          ),
          _ScaleSlider(
            label: 'qol_emotional'.tr(),
            hint: 'qol_emotional_hint'.tr(),
            value: _emotional,
            onChanged: (v) => setState(() => _emotional = v),
          ),
          SizedBox(height: 24.h),
          SizedBox(
            height: 50.h,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text('wellbeing_save_checkin'.tr(),
                  style: TextStyle(fontSize: 16.sp)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScaleSlider extends StatelessWidget {
  final String label;
  final String hint;
  final double value; // 0..10
  final ValueChanged<double> onChanged;
  const _ScaleSlider({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color = qolScoreColor(value);
    return Padding(
      padding: EdgeInsets.only(bottom: 18.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 15.sp, fontWeight: FontWeight.w700)),
              ),
              Container(
                width: 40.w,
                height: 30.h,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text('${value.round()}',
                    style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                        color: color)),
              ),
            ],
          ),
          Text(hint, style: TextStyle(fontSize: 12.sp, color: t.hintColor)),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              thumbColor: color,
              overlayColor: color.withValues(alpha: .15),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 10,
              divisions: 10,
              label: '${value.round()}',
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
