// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../services/infection_triage.dart';
// import '../viewmodel/analysis_result.dart';
// import 'ai_result_screen.dart';
//
// class AnalysisLoadingScreen extends StatefulWidget {
//   // final XFile file;
//   final String imagePath; // photo taken
//   const AnalysisLoadingScreen({super.key, required this.imagePath});
//
//   @override
//   State<AnalysisLoadingScreen> createState() => _AnalysisLoadingScreenState();
// }
//
// class _AnalysisLoadingScreenState extends State<AnalysisLoadingScreen> {
//   @override
//   void initState() {
//     super.initState();
//     _runAnalysis();
//   }
//
//   Future<void> _runAnalysis() async {
//     // Simulate AI call delay
//     await Future.delayed(const Duration(seconds: 3));
//
//     // Simulated AI result
//     final result = AnalysisResult(
//       length: 8.1,
//       width: 5.0,
//       depth: 3.2,
//       tissueType: 'Granulation',
//       pusLevel: 'Moderate',
//       inflammation: 'None',
//       healingProgress: 12,
//     );
//
//     if (!mounted) return;
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(builder: (_) => AiResultScreen(result: result)),
//     );
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     final t = Theme.of(context);
//     return Scaffold(
//       body: SafeArea(
//         child: Center(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               SizedBox(
//                 width: 56.w, height: 56.w,
//                 child:   LoadingAnimationWidget.hexagonDots(
//                   color:  const Color(0xff077FFF),
//                   size: 45.w,
//                 ),
//               ),
//               SizedBox(height: 16.h),
//               Text(
//                 'AI Wound Analysis',
//                 style: t.textTheme.titleMedium?.copyWith(
//                   color: t.colorScheme.primary,
//                   fontWeight: FontWeight.w600,
//                   fontSize: 16.sp,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
// import 'package:flutter/material.dart';
// import 'package:diafoot_care/features/wound/analysis/viewmodel/analysis_result.dart';
// import 'ai_result_screen.dart';
//
// class AnalysisLoadingScreen extends StatefulWidget {
//   final String imagePath; // photo taken
//   const AnalysisLoadingScreen({super.key, required this.imagePath});
//
//   @override
//   State<AnalysisLoadingScreen> createState() => _AnalysisLoadingScreenState();
// }
//
// class _AnalysisLoadingScreenState extends State<AnalysisLoadingScreen> {
//   @override
//   void initState() {
//     super.initState();
//     _runAnalysis();
//   }
//
//   Future<void> _runAnalysis() async {
//     // Simulate AI call delay
//     await Future.delayed(const Duration(seconds: 3));
//
//     // Simulated AI result
//     final result = AnalysisResult(
//       length: 8.1,
//       width: 5.0,
//       depth: 3.2,
//       tissueType: 'Granulation',
//       pusLevel: 'Moderate',
//       inflammation: 'None',
//       healingProgress: 12,
//     );
//
//     if (!mounted) return;
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(builder: (_) => AiResultScreen(result: result)),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return const Scaffold(body: Center(child: CircularProgressIndicator()));
//   }
// }

import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../services/ai_service.dart';  // ✅ Import AI service
import 'ai_result_screen.dart';
import '../../../../core/services/analysis_exception.dart';

class AnalysisLoadingScreen extends StatefulWidget {
  final String imagePath; // photo taken
  final double? pixelsPerCm; // from reference-object calibration (null = skipped)
  final double? manualDepthCm; // clinician's probe depth (null = not measured)

  /// Patient-reported IWGDF/IDSA signs, or null when the checklist was skipped.
  /// Null is passed through as "no answers", never as "all no" — an unanswered
  /// checklist is missing information, not a clean bill of health.
  final InfectionSigns? signs;

  const AnalysisLoadingScreen({
    super.key,
    required this.imagePath,
    this.pixelsPerCm,
    this.manualDepthCm,
    this.signs,
  });

  @override
  State<AnalysisLoadingScreen> createState() => _AnalysisLoadingScreenState();
}

class _AnalysisLoadingScreenState extends State<AnalysisLoadingScreen> {
  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    try {
      // ✅ Use real AI service to analyze the wound
      debugPrint('🔍 Analyzing wound image: ${widget.imagePath}');
      
      final result = await AiService.instance.analyzeWound(
        widget.imagePath,
        pixelsPerCm: widget.pixelsPerCm,
        manualDepthCm: widget.manualDepthCm,
      );

      if (!mounted) return;

      // The segmentation model ran but found no wound region (empty mask ->
      // length == width == 0). That means the photo isn't a foot wound (or the
      // wound is out of frame / too blurry). Don't save a 0×0 record or show a
      // meaningless result — tell the user and send them back to retake.
      final noWoundDetected =
          result.isFromModel && (result.length * result.width) <= 0;
      if (noWoundDetected) {
        debugPrint('ℹ️  No wound detected in image (0×0) — prompting retake.');
        await showAppMessage(
          context,
          title: 'no_wound_title'.tr(),
          message: 'no_wound_message'.tr(),
          kind: AppMessageKind.warning,
        );
        if (!mounted) return;
        Navigator.pop(context); // back to the camera to retake
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AiResultScreen(
            result: result,
            imagePath: widget.imagePath,
            signs: widget.signs,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Analysis error: $e');

      if (!mounted) return;

      // Prefer the specific reason over the generic one. "No connection —
      // you can switch to offline analysis in your profile" tells someone what
      // to do next; "analysis failed" leaves them stuck with a wound to
      // photograph and no idea why it did not work.
      await showAppError(
        context,
        e is AnalysisException ? e.message : 'analysis_failed'.tr(),
      );

      // Go back to previous screen
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 56.w,
                height: 56.w,
                child: LoadingAnimationWidget.hexagonDots(
                  color: const Color(0xff077FFF),
                  size: 45.w,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'ai_wound_analysis'.tr(),
                style: t.textTheme.titleMedium?.copyWith(
                  color: t.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16.sp,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'analyzing_photo'.tr(),
                style: t.textTheme.bodySmall?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
