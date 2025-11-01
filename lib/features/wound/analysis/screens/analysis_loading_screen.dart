// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:loading_animation_widget/loading_animation_widget.dart';
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
import '../viewmodel/analysis_result.dart';
import '../services/ai_service.dart';  // ✅ Import AI service
import 'ai_result_screen.dart';

class AnalysisLoadingScreen extends StatefulWidget {
  final String imagePath; // photo taken
  const AnalysisLoadingScreen({super.key, required this.imagePath});

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
      
      final result = await AiService.instance.analyzeWound(widget.imagePath);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AiResultScreen(
            result: result,
            imagePath: widget.imagePath,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Analysis error: $e');
      
      if (!mounted) return;
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('analysis_failed'.tr()),
          backgroundColor: Colors.red,
        ),
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
