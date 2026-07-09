import 'dart:io';
import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../../analysis/screens/analysis_loading_screen.dart';
import '../../analysis/screens/scale_calibration_screen.dart';

class PreviewScreen extends StatefulWidget {
  final XFile file;
  const PreviewScreen({super.key, required this.file});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  Future<Uint8List> _bytes() => widget.file.readAsBytes();

  /// Ask the user for the wound depth in cm. A single 2D photo can't yield
  /// depth, so the trustworthy source is a manual probe measurement. Returns
  /// the entered depth (> 0) or null if the user skips / leaves it empty.
  Future<double?> _askWoundDepth() async {
    final ctrl = TextEditingController();
    final result = await showDialog<double?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('wound_depth'.tr()),
          // Scrollable so the on-screen keyboard shrinking the dialog can never
          // overflow the content column.
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('wound_depth_hint'.tr(),
                    style: TextStyle(fontSize: 13.sp)),
                SizedBox(height: 14.h),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    labelText: 'wound_depth_cm'.tr(),
                    suffixText: 'cm',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text('skip'.tr()),
            ),
            FilledButton(
              onPressed: () {
                final v = double.tryParse(ctrl.text.trim());
                Navigator.pop(ctx, (v != null && v > 0) ? v : null);
              },
              child: Text('save'.tr()),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
    return result;
  }

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
            Text(
              'preview_hint'.tr(),
              style: t.textTheme.bodyMedium?.copyWith(
                fontSize: 14.sp,
                color: t.colorScheme.onSurface.withOpacity(.7),
              ),
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
                    child: ElevatedButton.icon(
                      onPressed: () async {
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

                        // Optional reference-object calibration for real-cm
                        // measurements. Returns px/cm, or null if skipped.
                        final pixelsPerCm = await Navigator.push<double?>(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => ScaleCalibrationScreen(
                                  imagePath: imagePath,
                                ),
                          ),
                        );

                        if (!mounted) return;
                        // Depth can't come from a 2D photo — ask for a manual
                        // probe measurement (optional).
                        final manualDepthCm = await _askWoundDepth();

                        if (!mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => AnalysisLoadingScreen(
                                  imagePath: imagePath,
                                  pixelsPerCm: pixelsPerCm,
                                  manualDepthCm: manualDepthCm,
                                ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: Text(
                        'save_and_continue'.tr(),
                        style: TextStyle(fontSize: 14.sp),
                      ),
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
