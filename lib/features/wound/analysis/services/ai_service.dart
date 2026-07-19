import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../viewmodel/analysis_result.dart';
import '../../../../core/services/app_mode_service.dart';
import '../../../../core/services/model_repository.dart';
import '../../../../core/services/remote_analysis_service.dart';

/// AI Service for wound analysis.
///
/// Model 1 — Wound SEGMENTATION (U-Net, MobileNetV2 + scSE decoder attention,
///   trained on FUSeg whole-foot photos + DFUTissue crops, ~0.86 val Dice).
///   Input [1,320,320,3] float32 (pixels /255, normalization baked in), output [1,320,320,1]
///   float32 probability mask. Post-processing (ported from the training
///   notebook): 2-view h-flip TTA, threshold (fallback 0.5×peak), 5×5 morphological
///   open+close, largest connected region -> AREA + rotated (PCA-axis) length/width.
///   DEPTH cannot be derived from a 2D photo: it comes from the clinician's manual
///   probe entry (or a future depth sensor). Never estimated from the mask.
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

  // Model 3 (infection & ischaemia): reuses the SAME CLIP backbone + small head
  Interpreter? _infectionHead;
  bool _model3Loaded = false;

  // ---- Model 1 config ----
  static const String _model1Path = 'assets/models/model1_wound_fp16.tflite';

  /// Mask threshold. 0.5 is the deployment default; the FUSeg-val-tuned optimum
  /// was ~0.73 but a high threshold shrinks the mask and biases AREA low, which
  /// matters more for measurement than the last Dice point. Keep 0.5 for sizing.
  static const double _maskThreshold = 0.5;

  /// Averaging the plain + horizontally-flipped prediction (2-view TTA) gives a
  /// steadier boundary for ~2x inference cost (~tens of ms on a phone). Set to
  /// false if analysis ever feels slow on low-end devices.
  static const bool _useFlipTta = true;

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

  // ---- Model 3 config (infection & ischaemia) ----
  // Same shared CLIP backbone -> tiny head. 4-class softmax over
  // [none, infection, ischaemia, both]. From it we derive two binaries:
  //   P(infection) = p[infection] + p[both];  P(ischaemia) = p[ischaemia] + p[both]
  // and apply the tuned thresholds below (from infection_ischaemia_head_meta.json).
  static const String _infectionHeadPath =
      'assets/models/infection_ischaemia_head.tflite';
  static const List<String> _infectionClasses = [
    'none', 'infection', 'ischaemia', 'both',
  ];
  // MLP head (512->256->4, label smoothing 0.05). Thresholds from
  // infection_ischaemia_head_meta.json (grouped-CV tuned):
  // infection AUC 0.890/F1 0.829, ischaemia AUC 0.987/F1 0.872.
  static const double _infectionThreshold = 0.41;
  static const double _ischaemiaThreshold = 0.61;

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
      _model1 = await _open(_model1Path);
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
      _clipBackbone = await _open(_clipPath);
      _tissueHead = await _open(_headPath);
      debugPrint('✅ Model 2 loaded. backbone out='
          '${_clipBackbone!.getOutputTensor(0).shape} head out='
          '${_tissueHead!.getOutputTensor(0).shape}');
      _model2Loaded = true;
    } catch (e) {
      debugPrint('⚠️  Failed to load Model 2: $e');
      _model2Loaded = false;
    }

    // Model 3 (infection & ischaemia head — shares Model 2's backbone)
    try {
      debugPrint('📦 Loading Model 3 (infection/ischaemia): head');
      _infectionHead = await _open(_infectionHeadPath);
      debugPrint('✅ Model 3 loaded. head out='
          '${_infectionHead!.getOutputTensor(0).shape}');
      _model3Loaded = true;
    } catch (e) {
      debugPrint('⚠️  Failed to load Model 3: $e');
      _model3Loaded = false;
    }

    _initialized = true;
  }

  /// Opens a model, preferring the downloaded copy over the bundled asset.
  ///
  /// [assetPath] is the asset key ('assets/models/foo.tflite'); its basename is
  /// also the name the server publishes the file under, so one path serves both.
  /// Downloaded files win because they are the ones the participant chose to
  /// fetch and whose checksums were verified on arrival, and because the assets
  /// are on their way out of the APK — once they are gone this is the only
  /// route that resolves.
  Future<Interpreter> _open(String assetPath) async {
    final name = assetPath.split('/').last;

    final downloaded = await ModelRepository.I.fileFor(name);
    if (await downloaded.exists() && await downloaded.length() > 0) {
      debugPrint('📦 $name from downloaded bundle');
      return Interpreter.fromFile(downloaded);
    }

    debugPrint('📦 $name from bundled assets');
    return Interpreter.fromAsset(assetPath);
  }

  /// Analyze a wound image: measurements (Model 1) + tissue type (Model 2).
  ///
  /// [pixelsPerCm] is the true scale (in ORIGINAL-image pixels per cm) obtained
  /// from reference-object calibration. If null, an uncalibrated estimate is
  /// used and the result is flagged `isCalibrated = false`.
  ///
  /// [manualDepthCm] is the wound depth measured by the clinician with a sterile
  /// probe. A single 2D photo physically cannot yield depth, so this is the only
  /// trustworthy source on a normal phone camera; when absent, depth is reported
  /// as 0 and the UI shows "not measured" instead of a fabricated number.
  Future<AnalysisResult> analyzeWound(String imagePath,
      {double? pixelsPerCm, double? manualDepthCm}) async {
    debugPrint('🔍 Analyzing wound image: $imagePath (ppc=$pixelsPerCm)');

    // Online mode analyses on the server. The participant chose not to keep
    // 200 MB of models on their phone, so this is the path that honours that
    // choice — and once the models leave the APK it is the only path they have.
    if (await AppModeService.I.current() == AppMode.online &&
        !imagePath.startsWith('assets/')) {
      try {
        final r = await RemoteAnalysisService.I.analyse(
          imagePath,
          pixelsPerCm: pixelsPerCm,
          manualDepthCm: manualDepthCm,
        );
        debugPrint('✅ Server analysis: ${r.riskBadge} / ${r.tissueType}');
        return r;
      } on RemoteAnalysisException catch (e) {
        // Falling back to the local models is only honest while they are still
        // on the device. When they are not, the failure has to surface:
        // inventing measurements for a wound is worse than saying so.
        await init();
        if (!_model1Loaded && !_model2Loaded) rethrow;
        debugPrint('⚠️  Server analysis failed (${e.message}); '
            'using the models on this device instead.');
      }
    }

    if (!_initialized) await init();

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
      // Depth comes ONLY from the clinician's probe entry (see doc above).
      double length = 0, width = 0, areaCm2 = 0;
      final double depth = manualDepthCm ?? 0.0;
      if (_model1Loaded) {
        final m = _runSegmentation(image, pixelsPerCm);
        length = m.lengthCm;
        width = m.widthCm;
        areaCm2 = m.areaCm2;
        debugPrint('✅ Model 1: L=${length.toStringAsFixed(2)}cm '
            'W=${width.toStringAsFixed(2)}cm area=${areaCm2.toStringAsFixed(2)}cm² '
            'D=${manualDepthCm == null ? "not measured" : depth.toStringAsFixed(2)}');
      }

      // --- Model 2 + Model 3: ONE CLIP backbone pass feeds both heads ---
      List<TissueFinding> tissueFindings = const [];
      String infectionStatus = 'N/A', ischaemiaStatus = 'N/A', riskBadge = 'Normal';
      if (_clipBackbone != null && (_model2Loaded || _model3Loaded)) {
        final emb = _clipEmbedding(image); // backbone runs ONCE per image
        if (_model2Loaded) {
          final probs = _runTissue(emb);
          tissueFindings = _buildTissueFindings(probs);
          debugPrint('✅ Model 2: $probs -> ${tissueFindings.summary}');
        }
        if (_model3Loaded) {
          final r = _runInfection(emb);
          infectionStatus = r.infection;
          ischaemiaStatus = r.ischaemia;
          riskBadge = r.badge;
          debugPrint('✅ Model 3: badge=$riskBadge '
              'infection=$infectionStatus ischaemia=$ischaemiaStatus');
        }
      }

      return AnalysisResult(
        length: length,
        width: width,
        depth: depth, // clinician-entered probe depth; 0 = not measured
        tissueFindings: tissueFindings,
        pusLevel: 'N/A', // legacy field — superseded by Model 3 infection/ischaemia
        inflammation: 'N/A', // legacy field — superseded by Model 3
        infection: infectionStatus,
        ischaemia: ischaemiaStatus,
        riskBadge: riskBadge,
        healingProgress: _calculateHealingProgress(areaCm2),
        isFromModel: true,
        isCalibrated: pixelsPerCm != null,
      );
    } catch (e, st) {
      debugPrint('❌ Inference error: $e\n$st');
      // Deliberately not a simulated result. Placeholder numbers returned from
      // a real analysis attempt are indistinguishable from a measurement once
      // they are on screen or in the record, and this is a wound.
      throw RemoteAnalysisException(
        'This photo could not be analysed on your phone. Please try again.',
      );
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

    // Probability map, optionally averaged with the h-flipped view (2-view TTA)
    // for a steadier wound boundary — mirrors the notebook's TTA evaluation.
    final probs = _predictProbs(resized, h, w, flip: false);
    if (_useFlipTta) {
      final flipped = _predictProbs(resized, h, w, flip: true);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          probs[y][x] = (probs[y][x] + flipped[y][x]) / 2.0;
        }
      }
    }

    // ---- Post-processing ported from the training notebook ----
    // 1) Binarize; if nothing clears the threshold, retry at half the peak
    //    response (handles an under-confident model).
    var mask = List.generate(
      h,
      (y) => List.generate(w, (x) => probs[y][x] >= _maskThreshold),
    );
    if (!mask.any((row) => row.any((v) => v))) {
      double peak = 0;
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          if (probs[y][x] > peak) peak = probs[y][x];
        }
      }
      if (peak <= 0) return const _Measurements(0, 0, 0);
      mask = List.generate(
        h,
        (y) => List.generate(w, (x) => probs[y][x] > 0.5 * peak),
      );
    }

    // 2) Morphological open then close (5×5) to drop specks and fill holes.
    mask = _morph5(_morph5(mask, dilate: false), dilate: true); // open
    mask = _morph5(_morph5(mask, dilate: true), dilate: false); // close

    // 3) Measure the largest connected region only (= largest contour).
    final comp = _largestComponent(mask);
    if (comp == null) return const _Measurements(0, 0, 0); // no wound found

    // 4) TRUE length/width via the wound's principal (PCA) axes — equivalent to
    //    cv2.minAreaRect in the notebook. The old axis-aligned bounding box
    //    over-measures any wound that lies diagonally in the frame.
    //    Uses anisotropic px sizes so non-square photos measure correctly.
    final sx = origW / w, sy = origH / h; // mask-px -> original-px scale
    final ext = _pcaExtentPx(mask, comp, sx, sy);
    final areaPx = comp.area * sx * sy;

    return _Measurements(
      ext.majorPx / ppc,
      ext.minorPx / ppc,
      areaPx / (ppc * ppc),
    );
  }

  /// One forward pass -> H×W probability map. When [flip] is true the input is
  /// mirrored horizontally and the output un-mirrored, so it aligns with the
  /// plain view for averaging.
  List<List<double>> _predictProbs(img.Image resized, int h, int w,
      {required bool flip}) {
    final input = List.generate(
      1,
      (_) => List.generate(
        h,
        (y) => List.generate(w, (x) {
          final p = resized.getPixel(flip ? w - 1 - x : x, y);
          return [p.rNormalized, p.gNormalized, p.bNormalized]; // r/255 etc.
        }),
      ),
    );
    final output = List.generate(
      1,
      (_) => List.generate(h, (_) => List.generate(w, (_) => List.filled(1, 0.0))),
    );
    _model1!.run(input, output);
    return List.generate(
      h,
      (y) => List.generate(
        w,
        (x) => (output[0][y][flip ? w - 1 - x : x][0] as num).toDouble(),
      ),
    );
  }

  /// Rotated extents of the largest component along its principal axes, in
  /// ORIGINAL-image pixels. PCA on the (anisotropically scaled) wound pixels
  /// gives the true major/minor axis even for diagonal wounds.
  _AxisExtent _pcaExtentPx(
      List<List<bool>> mask, _Component comp, double sx, double sy) {
    // Mean of wound pixel coordinates (in original-px units).
    double mx = 0, my = 0;
    int n = 0;
    for (int y = comp.minY; y <= comp.maxY; y++) {
      for (int x = comp.minX; x <= comp.maxX; x++) {
        if (!mask[y][x]) continue;
        mx += x * sx;
        my += y * sy;
        n++;
      }
    }
    if (n == 0) return const _AxisExtent(0, 0);
    mx /= n;
    my /= n;

    // 2x2 covariance -> principal axis angle.
    double cxx = 0, cyy = 0, cxy = 0;
    for (int y = comp.minY; y <= comp.maxY; y++) {
      for (int x = comp.minX; x <= comp.maxX; x++) {
        if (!mask[y][x]) continue;
        final dx = x * sx - mx, dy = y * sy - my;
        cxx += dx * dx;
        cyy += dy * dy;
        cxy += dx * dy;
      }
    }
    final theta = 0.5 * atan2(2 * cxy, cxx - cyy);
    final ct = cos(theta), st = sin(theta);

    // Project pixels onto the principal axes; extent = max - min (+1px width).
    double minU = double.infinity, maxU = -double.infinity;
    double minV = double.infinity, maxV = -double.infinity;
    for (int y = comp.minY; y <= comp.maxY; y++) {
      for (int x = comp.minX; x <= comp.maxX; x++) {
        if (!mask[y][x]) continue;
        final dx = x * sx - mx, dy = y * sy - my;
        final u = dx * ct + dy * st;
        final v = -dx * st + dy * ct;
        if (u < minU) minU = u;
        if (u > maxU) maxU = u;
        if (v < minV) minV = v;
        if (v > maxV) maxV = v;
      }
    }
    final e1 = (maxU - minU) + (sx + sy) / 2; // + ~1px: pixels have area
    final e2 = (maxV - minV) + (sx + sy) / 2;
    return _AxisExtent(max(e1, e2), min(e1, e2));
  }

  /// 5×5 binary dilation/erosion (cv2.morphologyEx kernel=ones((5,5))).
  /// Outside the frame counts as background for dilation and as wound for
  /// erosion, matching OpenCV's default border handling.
  List<List<bool>> _morph5(List<List<bool>> m, {required bool dilate}) {
    final h = m.length, w = m[0].length;
    const r = 2;
    final out = List.generate(h, (_) => List.filled(w, false));
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        var hit = false;
        for (int dy = -r; dy <= r && !hit; dy++) {
          for (int dx = -r; dx <= r && !hit; dx++) {
            final ny = y + dy, nx = x + dx;
            final inside = ny >= 0 && ny < h && nx >= 0 && nx < w;
            final v = inside ? m[ny][nx] : !dilate;
            if (dilate ? v : !v) hit = true;
          }
        }
        out[y][x] = dilate ? hit : !hit;
      }
    }
    return out;
  }

  /// Largest 8-connected region of the mask (area + bounding box).
  _Component? _largestComponent(List<List<bool>> m) {
    final h = m.length, w = m[0].length;
    final seen = List.generate(h, (_) => List.filled(w, false));
    _Component? best;
    for (int y0 = 0; y0 < h; y0++) {
      for (int x0 = 0; x0 < w; x0++) {
        if (!m[y0][x0] || seen[y0][x0]) continue;
        int area = 0, minX = x0, maxX = x0, minY = y0, maxY = y0;
        final stack = <int>[y0 * w + x0];
        seen[y0][x0] = true;
        while (stack.isNotEmpty) {
          final p = stack.removeLast();
          final y = p ~/ w, x = p % w;
          area++;
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
          for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
              final ny = y + dy, nx = x + dx;
              if (ny < 0 || ny >= h || nx < 0 || nx >= w) continue;
              if (m[ny][nx] && !seen[ny][nx]) {
                seen[ny][nx] = true;
                stack.add(ny * w + nx);
              }
            }
          }
        }
        if (best == null || area > best.area) {
          best = _Component(area, minX, minY, maxX, maxY);
        }
      }
    }
    return best;
  }

  // ---------------------------------------------------------------------------
  // Model 2 — tissue classification (CLIP backbone -> SVM head)
  // ---------------------------------------------------------------------------

  /// Run the shared CLIP backbone ONCE -> 512-d embedding [1,512].
  /// Both the tissue head (Model 2) and the infection head (Model 3) consume
  /// this same embedding, so the expensive backbone never runs twice per image.
  List _clipEmbedding(img.Image image) {
    final input = _clipPreprocess(image).reshape([1, 224, 224, 3]);
    final emb = List.filled(512, 0.0).reshape([1, 512]);
    _clipBackbone!.run(input, emb);
    return emb;
  }

  Map<String, double> _runTissue(List emb) {
    final probs = List.filled(_tissueClasses.length, 0.0)
        .reshape([1, _tissueClasses.length]);
    _tissueHead!.run(emb, probs);
    return {
      for (int c = 0; c < _tissueClasses.length; c++)
        _tissueClasses[c]: (probs[0][c] as num).toDouble(),
    };
  }

  /// Model 3: 512-d embedding -> 4-class softmax -> two binary readouts + badge.
  _InfectionResult _runInfection(List emb) {
    final probs = List.filled(_infectionClasses.length, 0.0)
        .reshape([1, _infectionClasses.length]);
    _infectionHead!.run(emb, probs);
    // order: [none, infection, ischaemia, both]
    final pInfection = (probs[0][1] as num).toDouble() + (probs[0][3] as num).toDouble();
    final pIschaemia = (probs[0][2] as num).toDouble() + (probs[0][3] as num).toDouble();
    final hasInfection = pInfection >= _infectionThreshold;
    final hasIschaemia = pIschaemia >= _ischaemiaThreshold;
    final badge = hasInfection && hasIschaemia
        ? 'High Risk'
        : hasInfection
            ? 'Infection Detected'
            : hasIschaemia
                ? 'Impaired Blood Flow'
                : 'Normal';
    return _InfectionResult(
      infection: hasInfection ? 'Present' : 'Not Present',
      ischaemia: hasIschaemia ? 'Impaired' : 'Adequate',
      badge: badge,
    );
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
  /// Builds one finding per tissue class: its probability, whether it cleared
  /// its own tuned threshold, and the threshold used.
  ///
  /// The head is multi-label, so every class is reported rather than a single
  /// winner. Which one to headline is a presentation decision, made by
  /// [TissueFindings.primaryType] from the same data.
  List<TissueFinding> _buildTissueFindings(Map<String, double> probs) {
    return _tissueClasses.map((name) {
      final p = probs[name] ?? 0.0;
      final threshold = _tissueThresholds[name] ?? 0.5;
      return TissueFinding(
        type: name,
        probability: p,
        isPresent: p >= threshold,
        thresholdUsed: threshold,
      );
    }).toList();
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
      infection: 'Not Present',
      ischaemia: 'Adequate',
      riskBadge: 'Normal',
      healingProgress: 45.0,
    );
  }

  bool get isModelLoaded => _model1Loaded || _model2Loaded || _model3Loaded;

  void dispose() {
    _model1?.close();
    _clipBackbone?.close();
    _tissueHead?.close();
    _infectionHead?.close();
    _model1 = null;
    _clipBackbone = null;
    _tissueHead = null;
    _infectionHead = null;
    _initialized = false;
    _model1Loaded = false;
    _model2Loaded = false;
    _model3Loaded = false;
    debugPrint('🗑️  AI service disposed');
  }
}

class _InfectionResult {
  final String infection; // 'Present' / 'Not Present'
  final String ischaemia; // 'Impaired' / 'Adequate'
  final String badge; // Normal / Infection Detected / Impaired Blood Flow / High Risk
  const _InfectionResult({
    required this.infection,
    required this.ischaemia,
    required this.badge,
  });
}

class _Measurements {
  final double lengthCm;
  final double widthCm;
  final double areaCm2;
  const _Measurements(this.lengthCm, this.widthCm, this.areaCm2);
}

/// Extents along the wound's principal axes, in original-image pixels.
class _AxisExtent {
  final double majorPx; // length
  final double minorPx; // width
  const _AxisExtent(this.majorPx, this.minorPx);
}

class _Component {
  final int area;
  final int minX, minY, maxX, maxY;
  const _Component(this.area, this.minX, this.minY, this.maxX, this.maxY);
}
