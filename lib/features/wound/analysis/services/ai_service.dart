import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../viewmodel/analysis_result.dart';

/// AI Service for wound analysis.
///
/// Model 1 — Wound SEGMENTATION (U-Net, MobileNetV2). Input [1,320,320,3]
///   float32 (pixels /255, normalization baked in), output [1,320,320,1]
///   float32 probability mask. We threshold the mask and measure it to get
///   wound length / width / area.
/// Model 2 — Tissue CLASSIFICATION (CLIP ViT-B/32 backbone + SVM head).
///   backbone: image[1,224,224,3] (CLIP-normalized) -> 512-d embedding;
///   head: 512-d -> 5 probabilities [epithelial, granulation, necrosis,
///   callus, slough]. A class is "present" if prob >= its threshold.
///
/// Web platform has no TFLite -> falls back to simulation data.
class AiService {
  static final AiService instance = AiService._();
  AiService._();

  bool _initialized = false;

  // Model 1 (segmentation)
  Interpreter? _model1;
  bool _model1Loaded = false;

  // Model 2 (tissue classification): two interpreters in sequence
  Interpreter? _clipBackbone;
  Interpreter? _tissueHead;
  bool _model2Loaded = false;

  // ---- Model 1 config ----
  static const String _model1Path = 'assets/models/model1_wound_fp16.tflite';
  static const double _maskThreshold = 0.5;

  /// When the photo is NOT calibrated with a reference object, we have no true
  /// scale. We assume the frame's wider side spans this many cm so the numbers
  /// are plausible (and the result is flagged `isCalibrated = false`). The
  /// reliable healing signal in that case is the relative AREA trend, not cm.
  static const double _assumedFrameCm = 12.0;

  // ---- Model 2 config ----
  static const String _clipPath = 'assets/models/clip_backbone_fp16.tflite';
  static const String _headPath = 'assets/models/tissue_head.tflite';
  static const List<String> _tissueClasses = [
    'epithelial', 'granulation', 'necrosis', 'callus', 'slough',
  ];
  // from tissue_head_meta.json
  static const Map<String, double> _tissueThresholds = {
    'epithelial': 0.09, 'granulation': 0.43, 'necrosis': 0.60,
    'callus': 0.45, 'slough': 0.63,
  };
  static const List<double> _clipMean = [0.48145466, 0.45782750, 0.40821073];
  static const List<double> _clipStd = [0.26862954, 0.26130258, 0.27577711];

  /// Initialize the AI service and load both models.
  Future<void> init() async {
    if (_initialized) return;

    if (kIsWeb) {
      debugPrint('ℹ️  Web platform: using simulation data (TFLite unavailable).');
      _initialized = true;
      return;
    }

    // Model 1
    try {
      debugPrint('📦 Loading Model 1 (segmentation): $_model1Path');
      _model1 = await Interpreter.fromAsset(_model1Path);
      debugPrint('✅ Model 1 loaded. in=${_model1!.getInputTensor(0).shape} '
          'out=${_model1!.getOutputTensor(0).shape}');
      _model1Loaded = true;
    } catch (e) {
      debugPrint('⚠️  Failed to load Model 1: $e');
      _model1Loaded = false;
    }

    // Model 2 (backbone is large ~168 MB)
    try {
      debugPrint('📦 Loading Model 2 (tissue): backbone + head');
      _clipBackbone = await Interpreter.fromAsset(_clipPath);
      _tissueHead = await Interpreter.fromAsset(_headPath);
      debugPrint('✅ Model 2 loaded. backbone out='
          '${_clipBackbone!.getOutputTensor(0).shape} head out='
          '${_tissueHead!.getOutputTensor(0).shape}');
      _model2Loaded = true;
    } catch (e) {
      debugPrint('⚠️  Failed to load Model 2: $e');
      _model2Loaded = false;
    }

    _initialized = true;
  }

  /// Analyze a wound image: measurements (Model 1) + tissue type (Model 2).
  ///
  /// [pixelsPerCm] is the true scale (in ORIGINAL-image pixels per cm) obtained
  /// from reference-object calibration. If null, an uncalibrated estimate is
  /// used and the result is flagged `isCalibrated = false`.
  Future<AnalysisResult> analyzeWound(String imagePath,
      {double? pixelsPerCm}) async {
    if (!_initialized) await init();
    debugPrint('🔍 Analyzing wound image: $imagePath (ppc=$pixelsPerCm)');

    if (kIsWeb || (!_model1Loaded && !_model2Loaded)) {
      await Future.delayed(const Duration(seconds: 2));
      debugPrint('⚠️  Analysis SIMULATED (models unavailable).');
      return _getSimulatedResult();
    }

    try {
      final bytes = await _loadImageBytes(imagePath);
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('Failed to decode image');
      // Apply EXIF orientation so pixel space matches the calibration screen.
      final image = img.bakeOrientation(decoded);

      // --- Model 1: segmentation -> measurements ---
      double length = 0, width = 0, areaCm2 = 0;
      if (_model1Loaded) {
        final m = _runSegmentation(image, pixelsPerCm);
        length = m.lengthCm;
        width = m.widthCm;
        areaCm2 = m.areaCm2;
        debugPrint('✅ Model 1: L=${length.toStringAsFixed(2)}cm '
            'W=${width.toStringAsFixed(2)}cm area=${areaCm2.toStringAsFixed(2)}cm²');
      }

      // --- Model 2: tissue classification ---
      String tissueType = 'Unknown';
      if (_model2Loaded) {
        final probs = _runTissue(image);
        tissueType = _pickTissueLabel(probs);
        debugPrint('✅ Model 2: $probs -> $tissueType');
      }

      return AnalysisResult(
        length: length,
        width: width,
        depth: 0.0, // segmentation cannot estimate depth
        tissueType: tissueType,
        pusLevel: 'N/A', // Model 3 (not built yet)
        inflammation: 'N/A', // Model 3 (not built yet)
        healingProgress: _calculateHealingProgress(areaCm2),
        isFromModel: true,
        isCalibrated: pixelsPerCm != null,
      );
    } catch (e, st) {
      debugPrint('❌ Inference error: $e\n$st');
      await Future.delayed(const Duration(seconds: 1));
      return _getSimulatedResult();
    }
  }

  // ---------------------------------------------------------------------------
  // Model 1 — segmentation
  // ---------------------------------------------------------------------------

  _Measurements _runSegmentation(img.Image image, double? pixelsPerCm) {
    final inShape = _model1!.getInputTensor(0).shape; // [1,320,320,3]
    final h = inShape[1], w = inShape[2];
    final origW = image.width, origH = image.height;
    // px/cm in ORIGINAL-image space. If uncalibrated, assume the wider side
    // spans `_assumedFrameCm` so values are plausible (scales with resolution).
    final ppc = pixelsPerCm ?? (max(origW, origH) / _assumedFrameCm);

    // Resize to model input; normalization (/255) is the only step the model
    // expects (mean/std are baked into the graph).
    final resized = img.copyResize(image, width: w, height: h);
    final input = List.generate(
      1,
      (_) => List.generate(
        h,
        (y) => List.generate(w, (x) {
          final p = resized.getPixel(x, y);
          return [p.rNormalized, p.gNormalized, p.bNormalized]; // r/255 etc.
        }),
      ),
    );

    // Output mask [1,H,W,1].
    final output = List.generate(
      1,
      (_) => List.generate(h, (_) => List.generate(w, (_) => List.filled(1, 0.0))),
    );
    _model1!.run(input, output);

    // Threshold + bounding box of the wound.
    int area = 0, minX = w, minY = h, maxX = -1, maxY = -1;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        if (output[0][y][x][0] >= _maskThreshold) {
          area++;
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < 0) return const _Measurements(0, 0, 0); // no wound found

    // Scale mask-space (320) pixels back to original-image pixels.
    final sx = origW / w, sy = origH / h;
    final widthPx = (maxX - minX + 1) * sx;
    final lengthPx = (maxY - minY + 1) * sy;
    final areaPx = area * sx * sy;
    return _Measurements(
      lengthPx / ppc,
      widthPx / ppc,
      areaPx / (ppc * ppc),
    );
  }

  // ---------------------------------------------------------------------------
  // Model 2 — tissue classification (CLIP backbone -> SVM head)
  // ---------------------------------------------------------------------------

  Map<String, double> _runTissue(img.Image image) {
    final input = _clipPreprocess(image).reshape([1, 224, 224, 3]);
    final emb = List.filled(512, 0.0).reshape([1, 512]);
    _clipBackbone!.run(input, emb);
    final probs = List.filled(_tissueClasses.length, 0.0)
        .reshape([1, _tissueClasses.length]);
    _tissueHead!.run(emb, probs);
    return {
      for (int c = 0; c < _tissueClasses.length; c++)
        _tissueClasses[c]: (probs[0][c] as num).toDouble(),
    };
  }

  /// CLIP preprocessing: resize shorter side to 224 (bicubic), center-crop 224,
  /// /255, then per-channel normalize. MUST match training or accuracy collapses.
  Float32List _clipPreprocess(img.Image src) {
    final scale = 224 / min(src.width, src.height);
    final rz = img.copyResize(
      src,
      width: (src.width * scale).round(),
      height: (src.height * scale).round(),
      interpolation: img.Interpolation.cubic,
    );
    final x0 = ((rz.width - 224) / 2).round();
    final y0 = ((rz.height - 224) / 2).round();
    final crop = img.copyCrop(rz, x: x0, y: y0, width: 224, height: 224);

    final out = Float32List(224 * 224 * 3);
    int i = 0;
    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final p = crop.getPixel(x, y);
        out[i++] = (p.rNormalized - _clipMean[0]) / _clipStd[0];
        out[i++] = (p.gNormalized - _clipMean[1]) / _clipStd[1];
        out[i++] = (p.bNormalized - _clipMean[2]) / _clipStd[2];
      }
    }
    return out;
  }

  /// Choose one tissue label for the UI: the highest-probability class that is
  /// "present" (>= its threshold); if none qualifies, the overall argmax.
  String _pickTissueLabel(Map<String, double> probs) {
    String? best;
    double bestProb = -1;
    probs.forEach((name, p) {
      if (p >= (_tissueThresholds[name] ?? 0.5) && p > bestProb) {
        best = name;
        bestProb = p;
      }
    });
    if (best == null) {
      probs.forEach((name, p) {
        if (p > bestProb) {
          best = name;
          bestProb = p;
        }
      });
    }
    final label = best ?? 'unknown';
    return label[0].toUpperCase() + label.substring(1);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<Uint8List> _loadImageBytes(String imagePath) async {
    if (imagePath.startsWith('assets/')) {
      final byteData = await rootBundle.load(imagePath);
      return byteData.buffer.asUint8List();
    }
    return File(imagePath).readAsBytes();
  }

  /// Healing progress from wound area. NOTE: a true value needs the patient's
  /// baseline area from history; here we use a coarse reference so the UI shows
  /// a sane number. Replace with (baselineArea - currentArea)/baselineArea.
  double _calculateHealingProgress(double areaCm2) {
    const baselineArea = 100.0;
    return ((baselineArea - areaCm2) / baselineArea * 100).clamp(0.0, 100.0);
  }

  AnalysisResult _getSimulatedResult() {
    debugPrint('⚠️  Using simulated AI data');
    return AnalysisResult(
      length: 8.1,
      width: 5.0,
      depth: 3.2,
      tissueType: 'Granulation',
      pusLevel: 'Moderate',
      inflammation: 'None',
      healingProgress: 45.0,
    );
  }

  bool get isModelLoaded => _model1Loaded || _model2Loaded;

  void dispose() {
    _model1?.close();
    _clipBackbone?.close();
    _tissueHead?.close();
    _model1 = null;
    _clipBackbone = null;
    _tissueHead = null;
    _initialized = false;
    _model1Loaded = false;
    _model2Loaded = false;
    debugPrint('🗑️  AI service disposed');
  }
}

class _Measurements {
  final double lengthCm;
  final double widthCm;
  final double areaCm2;
  const _Measurements(this.lengthCm, this.widthCm, this.areaCm2);
}
