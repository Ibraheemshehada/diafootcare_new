import 'package:flutter/foundation.dart' show kIsWeb, ChangeNotifier;
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';

class CaptureViewModel extends ChangeNotifier {
  final ImagePicker _picker = ImagePicker();
  XFile? lastImage;
  bool isBusy = false;

  CameraController? _controller;           // mobile only
  CameraController? get controller => _controller;

  bool _initialized = false;
  bool get isInitialized => _initialized && (kIsWeb || (_controller?.value.isInitialized ?? false));

  Future<void> init() async {
    if (kIsWeb) {
      // ✅ Web: nothing to init — mark ready right away
      _initialized = true;
      notifyListeners();
      return;
    }
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      _controller = CameraController(back, ResolutionPreset.high, enableAudio: false);
      await _controller!.initialize();
      _initialized = true;
      notifyListeners();
    } catch (_) {
      _initialized = true;  // still allow shutter to open picker on web/mobile fallback
      notifyListeners();
    }
  }

  /// Picks an existing photograph instead of taking one.
  ///
  /// Wounds are often photographed by someone else — a district nurse, a family
  /// member holding the foot — or through a dressing change when the phone was
  /// not to hand. Forcing a live capture means those photos never get analysed,
  /// or get re-photographed off a screen, which is worse.
  ///
  /// Returns null when the picker is dismissed, which is not an error.
  Future<XFile?> pickFromGallery() async {
    if (isBusy) return null;
    isBusy = true;
    notifyListeners();
    try {
      // No maxWidth/maxHeight: image_picker would resample before the analysis
      // sees the file, and the measurements are taken from the pixels. Resizing
      // happens later, once, in a place that knows what it is for.
      final x = await _picker.pickImage(source: ImageSource.gallery);
      if (x != null) lastImage = x;
      return x;
    } catch (_) {
      return null;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<XFile?> takePicture() async {
    if (isBusy) return null;
    isBusy = true; notifyListeners();
    try {
      if (kIsWeb) {
        final x = await _picker.pickImage(source: ImageSource.camera);
        lastImage = x;
        return x;
      } else {
        if (!(_controller?.value.isInitialized ?? false)) return null;
        final x = await _controller!.takePicture();
        lastImage = x;
        return x;
      }
    } finally {
      isBusy = false; notifyListeners();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
