import 'dart:io';
import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../../analysis/screens/analysis_loading_screen.dart';

class PreviewScreen extends StatefulWidget {
  final XFile file;
  const PreviewScreen({super.key, required this.file});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  Future<Uint8List> _bytes() => widget.file.readAsBytes();
  
  Future<String> _saveImageToLocal() async {
    try {
      // Get app documents directory
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String fileName = 'wound_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
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
        title: Text('preview_your_photo'.tr(), style: TextStyle(fontSize: 18.sp)),
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
                  child: SizedBox(
                    height: 48.h,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // Show loading
                        if (mounted) {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const Center(child: CircularProgressIndicator()),
                          );
                        }

                        // Save image to local storage
                        final imagePath = await _saveImageToLocal();

                        if (mounted) {
                          Navigator.pop(context); // Close loading dialog
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AnalysisLoadingScreen(imagePath: imagePath),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: Text('save_and_continue'.tr(), style: TextStyle(fontSize: 14.sp)),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: SizedBox(
                    height: 48.h,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.refresh),
                      label: Text('retake_photo'.tr(), style: TextStyle(fontSize: 14.sp)),
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
