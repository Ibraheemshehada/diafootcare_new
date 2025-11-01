import 'package:camera/camera.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../viewmodel/capture_viewmodel.dart';
import '../widgets/shutter_button.dart';
import '../widgets/capture_tips_dialog.dart';
import 'preview_screen.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> with WidgetsBindingObserver {
  bool _tipsShown = false;

  Future<void> _checkAndShowTips(BuildContext context) async {
    if (_tipsShown || !mounted) return;
    
    final prefs = await SharedPreferences.getInstance();
    final dontShowAgain = prefs.getBool('capture_tips_dont_show') ?? false;
    
    if (dontShowAgain) {
      debugPrint('📋 Tips dialog skipped - user selected "Don\'t show again"');
      return;
    }
    
    // Mark as shown to prevent multiple dialogs
    _tipsShown = true;
    
    // Wait a bit to ensure screen is fully rendered
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (!mounted) return;
    
    debugPrint('📋 Showing capture tips dialog');
    
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CaptureTipsDialog(),
    );
    
    debugPrint('📋 Dialog result: $result');
    
    if (result == 'dont_show' && mounted) {
      await prefs.setBool('capture_tips_dont_show', true);
      debugPrint('📋 Saved "Don\'t show again" preference');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Show tips after screen is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkAndShowTips(context);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reset tips when app comes back to foreground (optional)
    if (state == AppLifecycleState.resumed) {
      // Could reset _tipsShown here if you want to show tips again after app resume
    }
  }

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

                // Preview area - full width
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.r),
                    child: Container(
                      color: Colors.black12,
                      child: _PreviewArea(vm: vm),
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
    return SizedBox(
      width: double.infinity,
      child: CameraPreview(vm.controller!),
    );
  }
}
