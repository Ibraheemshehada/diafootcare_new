import 'dart:async';

import 'package:camera/camera.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../services/live_frame_check.dart';
import '../../analysis/services/ring_detector.dart';

/// A camera that tells the patient what is wrong **while they are still aiming**.
///
/// The old flow took the photograph first and judged it afterwards. By then the
/// dressing is back on and nobody retakes anything, so a bad angle simply became
/// a bad measurement. Ten of 26 clinic photographs were past 40°, where measured
/// error reaches 56% — this is the common case.
///
/// Three decisions worth stating:
///
/// **The shutter is disabled, not the photograph refused.** A greyed-out button
/// with a reason beside it teaches the movement; a rejection after the fact
/// teaches nothing.
///
/// **No label in view still allows a photograph.** The check cannot see, so it
/// does not judge — some clinics photograph without the label and their scans
/// are measured as estimates, which is better than a locked camera.
///
/// **The words are short and plain.** They are read at arm's length, one-handed,
/// over someone's foot, often by a patient rather than a clinician.
class LiveCaptureScreen extends StatefulWidget {
  const LiveCaptureScreen({super.key});

  @override
  State<LiveCaptureScreen> createState() => _LiveCaptureScreenState();
}

class _LiveCaptureScreenState extends State<LiveCaptureScreen> {
  CameraController? _cam;
  bool _ready = false;
  String? _error;

  RingDetection? _ring;
  LiveGuide _guide = LiveGuide.noLabel;

  /// Frames arrive far faster than they can be read. One analysis at a time,
  /// and no more than a few a second: the guidance only has to keep up with a
  /// hand moving, and a queue of stale frames would make it lag behind one.
  bool _busy = false;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  static const _minGap = Duration(milliseconds: 350);

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        setState(() => _error = 'live_no_camera'.tr());
        return;
      }
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      // Medium, not max: the preview stream is for guidance, and the photograph
      // itself is taken at full resolution by takePicture().
      final c = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: previewFormat,
      );
      await c.initialize();
      await c.startImageStream(_onFrame);
      if (!mounted) return;
      setState(() {
        _cam = c;
        _ready = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'live_camera_failed'.tr());
    }
  }

  void _onFrame(CameraImage frame) {
    if (_busy || DateTime.now().difference(_last) < _minGap) return;
    _busy = true;
    _last = DateTime.now();
    // Synchronous on purpose: the conversion is already cheap at 320 px, and an
    // isolate hop per frame costs more than the work it would move.
    final ring = LiveFrameCheck.read(frame);
    _busy = false;
    if (!mounted) return;
    final g = guideFor(ring);
    if (g != _guide || (ring?.tiltDeg ?? -1) != (_ring?.tiltDeg ?? -1)) {
      setState(() {
        _ring = ring;
        _guide = g;
      });
    }
  }

  Future<void> _shoot() async {
    final c = _cam;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.stopImageStream();
      final shot = await c.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(XFile(shot.path));
    } catch (_) {
      if (mounted) setState(() => _error = 'live_capture_failed'.tr());
    }
  }

  @override
  void dispose() {
    _cam?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text('live_title'.tr())),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15.sp)),
          ),
        ),
      );
    }
    if (!_ready || _cam == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final (bg, icon) = switch (_guide) {
      LiveGuide.ready => (const Color(0xFF1B8A3A), Icons.check_circle),
      LiveGuide.almost => (const Color(0xFFB06E00), Icons.trending_flat),
      LiveGuide.tooAngled => (const Color(0xFFC62828), Icons.warning_amber_rounded),
      LiveGuide.noLabel => (const Color(0xFF37474F), Icons.crop_free),
    };

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('live_title'.tr(), style: TextStyle(fontSize: 16.sp)),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                CameraPreview(_cam!),

                // Where to put the wound. A frame to aim inside is easier to
                // follow than any sentence about framing.
                IgnorePointer(
                  child: Container(
                    width: 260.w,
                    height: 260.w,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.white.withValues(alpha: .55), width: 2),
                      borderRadius: BorderRadius.circular(18.r),
                    ),
                  ),
                ),

                // The live verdict, big and at the top where a thumb is not
                // covering it.
                Positioned(
                  top: 12.h,
                  left: 12.w,
                  right: 12.w,
                  child: _GuideBar(
                    colour: bg,
                    icon: icon,
                    text: _guide.key.tr(),
                    tilt: _ring?.tiltDeg,
                  ),
                ),
              ],
            ),
          ),

          // The conditions, always visible, ticking themselves off. A patient
          // can see what is already right instead of guessing what is wrong.
          Container(
            width: double.infinity,
            color: const Color(0xFF111417),
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Condition(
                  done: _ring != null,
                  text: 'live_cond_label'.tr(),
                ),
                _Condition(
                  done: _ring != null && _ring!.tiltDeg <= 30,
                  text: 'live_cond_flat'.tr(),
                ),
                _Condition(
                  done: _guide == LiveGuide.ready,
                  text: 'live_cond_round'.tr(),
                ),
              ],
            ),
          ),

          Container(
            color: const Color(0xFF111417),
            padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 18.h),
            child: Row(
              children: [
                Expanded(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: 52.h),
                    child: ElevatedButton.icon(
                      onPressed: _guide.canShoot ? _shoot : null,
                      icon: const Icon(Icons.camera_alt),
                      label: Text(
                        _guide.canShoot
                            ? 'live_take_photo'.tr()
                            : 'live_fix_first'.tr(),
                        style: TextStyle(
                            fontSize: 15.sp, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideBar extends StatelessWidget {
  final Color colour;
  final IconData icon;
  final String text;
  final double? tilt;

  const _GuideBar({
    required this.colour,
    required this.icon,
    required this.text,
    this.tilt,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
          if (tilt != null)
            Text(
              '${tilt!.round()}°',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

class _Condition extends StatelessWidget {
  final bool done;
  final String text;
  const _Condition({required this.done, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3.h),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18.sp,
            color: done ? const Color(0xFF4CD07D) : Colors.white38,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: done ? Colors.white : Colors.white60,
                fontSize: 13.sp,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
