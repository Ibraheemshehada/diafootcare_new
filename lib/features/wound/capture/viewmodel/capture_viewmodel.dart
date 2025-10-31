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
