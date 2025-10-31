import 'package:camera/camera.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../viewmodel/capture_viewmodel.dart';
import '../widgets/shutter_button.dart';
import 'preview_screen.dart';

class CaptureScreen extends StatelessWidget {
  const CaptureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CaptureViewModel()..init(),
      child: Consumer<CaptureViewModel>(
        builder: (context, vm, _) {
          final t = Theme.of(context);
          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Text(
                    'take_wound_photo'.tr(),
                    style: t.textTheme.titleLarge?.copyWith(fontSize: 20.sp),
                  ),
                ),
                SizedBox(height: 12.h),

                // Preview area
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16.r),
                      child: Container(
                        color: Colors.black12,
                        child: _PreviewArea(vm: vm),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 12.h),
                Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: ShutterButton(
                      disabled: vm.isBusy || !vm.isInitialized,
                      onPressed: () async {
                        final shot = await vm.takePicture();
                        if (shot == null || !context.mounted) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => PreviewScreen(file: shot)),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PreviewArea extends StatelessWidget {
  const _PreviewArea({required this.vm});
  final CaptureViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Web: no loader, just a hint
      return Center(
        child: Text(
          'web_shutter_hint'.tr(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 14.sp,
            color: Colors.white,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
          ),
        ),
      );
    }

    if (!vm.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return CameraPreview(vm.controller!);
  }
}
