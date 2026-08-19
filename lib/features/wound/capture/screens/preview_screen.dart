import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show FontFeature;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../../analysis/screens/analysis_loading_screen.dart';
import '../../analysis/screens/infection_checklist_screen.dart';
import '../../analysis/services/infection_triage.dart';
import '../services/capture_check.dart';

class PreviewScreen extends StatefulWidget {
  final XFile file;
  const PreviewScreen({super.key, required this.file});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  Future<Uint8List> _bytes() => widget.file.readAsBytes();

  /// Checked once, here, rather than after the analysis. A patient who has to be
  /// told the photograph was too angled has already put the phone down by then,
  /// and the wound is dressed again.
  late final Future<CaptureCheck> _check =
      const CaptureChecker().check(widget.file.path);

  Future<String> _saveImageToLocal() async {
    try {
      // Get app documents directory
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String fileName =
          'wound_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String savedPath = path.join(appDocDir.path, fileName);

      // Copy the file to app directory
      await File(widget.file.path).copy(savedPath);

      debugPrint('✅ Image saved to: $savedPath');
      return savedPath;
    } catch (e) {
      debugPrint('❌ Error saving image: $e');
      // Fallback to original path
      return widget.file.path;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'preview_your_photo'.tr(),
          style: TextStyle(fontSize: 18.sp),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14.r),
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFFF2F2F2),
                  child: FutureBuilder<Uint8List>(
                    future: _bytes(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return Image.memory(
                        snap.data!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      );
                    },
                  ),
                ),
              ),
            ),
            SizedBox(height: 14.h),
            FutureBuilder<CaptureCheck>(
              future: _check,
              builder: (context, snap) => _AngleBanner(check: snap.data),
            ),
            SizedBox(height: 14.h),
            Row(
              children: [
                Expanded(
                  child: ConstrainedBox(
                    // minHeight (not an exact height): keeps the >=48dp touch
                    // target while letting the button grow when the user
                    // enlarges the system font. An exact height clipped labels.
                    constraints: BoxConstraints(minHeight: 48.h),
                    child: FutureBuilder<CaptureCheck>(
                      future: _check,
                      builder: (context, snap) {
                        final blocked = snap.data?.blocks ?? false;
                        final waiting = !snap.hasData;
                        return ElevatedButton.icon(
                      // Disabled while the check runs and refused when the ring
                      // proves the angle is past 40°, where measured error
                      // triples. Nothing is blocked on a guess: a photograph
                      // with no ring in it cannot be judged, so it is allowed.
                      onPressed: (blocked || waiting) ? null : () async {
                        // Show loading
                        if (mounted) {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder:
                                (_) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                          );
                        }

                        // Save image to local storage
                        final imagePath = await _saveImageToLocal();

                        if (!mounted) return;
                        Navigator.pop(context); // Close loading dialog

                        if (!mounted) return;
                        // The photo answers only part of the question. A camera
                        // can see redness but cannot feel warmth or tenderness,
                        // and IWGDF/IDSA needs those signs — so the checklist
                        // sits between the photo and the analysis, collecting
                        // what the lens cannot. Skipping it is allowed; the
                        // triage then simply has fewer signs to count.
                        // (Scale calibration and manual depth were removed
                        // earlier; measurements run uncalibrated and are
                        // flagged as approximate on the result.)
                        final signs = await Navigator.push<InfectionSigns>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const InfectionChecklistScreen(),
                          ),
                        );
                        if (!context.mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => AnalysisLoadingScreen(
                                  imagePath: imagePath,
                                  signs: signs,
                                ),
                          ),
                        );
                      },
                      icon: Icon(waiting
                          ? Icons.hourglass_empty
                          : blocked
                              ? Icons.block
                              : Icons.bookmark_add_outlined),
                      label: Text(
                        waiting
                            ? 'capture_checking'.tr()
                            : 'save_and_continue'.tr(),
                        style: TextStyle(fontSize: 14.sp),
                      ),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ConstrainedBox(
                    // minHeight (not an exact height): keeps the >=48dp touch
                    // target while letting the button grow when the user
                    // enlarges the system font. An exact height clipped labels.
                    constraints: BoxConstraints(minHeight: 48.h),
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        'retake_photo'.tr(),
                        style: TextStyle(fontSize: 14.sp),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The verdict on this photograph, and what to do about it.
///
/// Colour carries the meaning before the words do: green passes, amber is a
/// nudge, red is a refusal. The tilt itself is shown because a number the
/// patient can watch change is what teaches the movement — "hold it flatter"
/// means nothing until 47° becomes 22°.
class _AngleBanner extends StatelessWidget {
  final CaptureCheck? check;
  const _AngleBanner({required this.check});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    if (check == null) {
      return Row(
        children: [
          SizedBox(
            width: 16.w,
            height: 16.w,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10.w),
          Text('capture_checking'.tr(),
              style: t.textTheme.bodyMedium?.copyWith(fontSize: 13.sp)),
        ],
      );
    }

    final c = check!;
    final (bg, fg, icon) = switch (c.verdict) {
      CaptureVerdict.good => (
          const Color(0xFFE8F5E9),
          const Color(0xFF1B5E20),
          Icons.check_circle_outline
        ),
      CaptureVerdict.marginal => (
          const Color(0xFFFFF8E1),
          const Color(0xFF8D6E00),
          Icons.info_outline
        ),
      CaptureVerdict.tooAngled => (
          const Color(0xFFFFEBEE),
          const Color(0xFFB71C1C),
          Icons.error_outline
        ),
      _ => (
          const Color(0xFFF3F3F3),
          const Color(0xFF555555),
          Icons.help_outline
        ),
    };

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 20.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.title,
                        style: t.textTheme.titleSmall?.copyWith(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
                    ),
                    if (c.tiltDeg != null)
                      Text(
                        'capture_tilt_reading'
                            .tr(args: [c.tiltDeg!.round().toString()]),
                        style: t.textTheme.bodySmall?.copyWith(
                          fontSize: 12.sp,
                          color: fg,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  c.body,
                  style: t.textTheme.bodySmall
                      ?.copyWith(fontSize: 12.sp, color: fg, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
