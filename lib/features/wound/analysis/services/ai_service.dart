import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../viewmodel/analysis_result.dart';
import '../../../../core/services/analysis_exception.dart';
import '../../../../core/services/app_mode_service.dart';
import '../../../../core/services/model_repository.dart';
import '../../../../core/services/remote_analysis_service.dart';

/// Is this masked region printed ink on a white card rather than tissue?
///
/// Judged on the collar just outside the region — a band 4 px wide, matching
/// the two 5×5 dilations the rule was validated with on 153 clinic photographs.
/// Printed ink sits on a white card, tissue sits in skin, so what surrounds a
/// blob separates the two where colour cannot: vivid granulation occupies the
/// same magenta hue band as the small label's ring.
///
/// Free of the `image` package and of any model, so it can be tested directly:
/// [isPaper] answers whether the pixel at (x, y) is white card.
///
/// [ids] is a region-id grid (0 = background), [box] is
/// `[minX, minY, maxX, maxY, ...]` for the region being judged.
bool isPrintedLabelRegion({
  required List<List<int>> ids,
  required int id,
  required List<int> box,
  required bool Function(int x, int y) isPaper,
  double whiteSurround = 0.40,
  int radius = 4,
}) {
  final h = ids.length;
  if (h == 0) return false;
  final w = ids[0].length;
  final x0 = max(0, box[0] - radius), y0 = max(0, box[1] - radius);
  final x1 = min(w - 1, box[2] + radius), y1 = min(h - 1, box[3] + radius);

  int collar = 0, paper = 0;
  for (int y = y0; y <= y1; y++) {
    for (int x = x0; x <= x1; x++) {
      if (ids[y][x] == id) continue; // inside the region, not its collar
      var touches = false;
      for (int dy = -radius; dy <= radius && !touches; dy++) {
        for (int dx = -radius; dx <= radius && !touches; dx++) {
          final ny = y + dy, nx = x + dx;
          if (ny < 0 || ny >= h || nx < 0 || nx >= w) continue;
          if (ids[ny][nx] == id) touches = true;
        }
      }
      if (!touches) continue;
      collar++;
      if (isPaper(x, y)) paper++;
    }
  }
  // No collar at all means the region fills the frame; refusing it would delete
  // a wound photographed very close up, so an unanswerable question is a "no".
  if (collar == 0) return false;
  return paper / collar >= whiteSurround;
}

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

  /// Refuse to measure the printed calibration label.
  ///
  /// The segmenter reads the small magenta ring as granulation tissue. Across
  /// 153 clinic photographs it measured the **label instead of the wound** in
  /// 40% of small-label shots (10 of 25; never on the 102 standard cyan ones),
  /// and since the ring is 15 mm it returned 1.5 cm — which matched one
  /// patient's clinical figure exactly, by pure coincidence. A wrong number
  /// that agrees with the clinician is the most dangerous kind, because nothing
  /// flags it.
  ///
  /// The test is deliberately **not** "is this blob magenta": vivid granulation
  /// occupies the same hue band, and a colour rule threw away real wounds. It
  /// asks what SURROUNDS the blob instead — printed ink sits on a white card,
  /// tissue sits in skin. On those 153 photographs the ten labels that were
  /// actually measured scored 0.59–0.87 white surround, and the 126 real wounds
  /// scored at most 0.25, so this threshold sits in a gap of 0.34 with nothing
  /// in it.
  ///
  /// Needs no ring detection, no calibration and no extra inference: it reads
  /// the same resized buffer the segmenter was already given.
  /// See docs/IMPLEMENTATION_TRACKER.md C21/C25 and FINDINGS.md §10.
  static const bool _refusePrintedLabel = true;
  static const double _labelWhiteSurround = 0.40;

  /// White-card pixel: pale and unsaturated. Skin under flash is brighter than
  /// it is grey, so saturation is what carries this test.
  static const double _paperMaxSat = 50 / 255;
  static const double _paperMinVal = 170 / 255;

  /// Crop Model 3's input to the wound Model 1 located.
  ///
  /// Model 3 was trained **exclusively on tight wound patches** — DFUC2021 at
  /// 224×224 and Part B at 256×256 — and has never seen a whole foot. The app
  /// was handing it a centre crop of a whole-foot photograph, which is perhaps
  /// 5% wound and 95% skin, floor and background: a train/serve mismatch, and
  /// the most likely cause of a false "Infection Detected" on a healthy wound.
  /// Cropping restores the framing the head was actually trained on.
  ///
  /// **Model 2 is deliberately NOT cropped**: its corpora (Source-A, DFUC2020)
  /// are whole photographs, so cropping it would *create* the same mismatch in
  /// the opposite direction. It stays on the whole frame until its head is
  /// retrained on crops.
  ///
  /// Set false to restore the previous single-pass behaviour.
  /// See docs/ACCURACY_IMPROVEMENT_PLAN.md §3 (W2a).
  static const bool _cropForModel3 = true;

  /// Padding added on each side of the wound box, as a fraction of its larger
  /// side, so a little peri-wound skin stays in frame as in the training patches.
  static const double _model3CropPadding = 0.15;

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
  /// Loads the interpreters, yielding to the event loop between each.
  ///
  /// `Interpreter.fromFile` is synchronous native work: building the ~168 MB
  /// CLIP backbone blocks whichever isolate calls it, and the interpreters hold
  /// native pointers so they cannot be built in a background isolate and used
  /// from this one. Loading all four back to back therefore froze the UI long
  /// enough for Android to raise "DiaFootCare isn't responding" as soon as the
  /// camera screen opened.
  ///
  /// The models still load on this isolate — that part is unavoidable without
  /// moving inference wholesale into an isolate of its own — but a frame is
  /// pumped between each one, so the UI stays responsive and the ANR watchdog
  /// (5 s of an unhandled input event) is never reached.
  Future<void> init() async {
    if (_initialized) return;
    // Never two loads at once: the camera screen calls this on every open, and
    // a second pass while the first is still running doubles the stall.
    if (_initialising != null) return _initialising;
    final done = Completer<void>();
    _initialising = done.future;
    try {
      await _initInner();
    } finally {
      _initialising = null;
      done.complete();
    }
  }

  Future<void>? _initialising;

  /// Lets the platform draw a frame before the next blocking load.
  Future<void> _breathe() =>
      Future<void>.delayed(const Duration(milliseconds: 16));

  Future<void> _initInner() async {

    if (kIsWeb) {
      debugPrint('ℹ️  Web platform: using simulation data (TFLite unavailable).');
      _initialized = true;
      return;
    }

    await _breathe();

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

    await _breathe();

    // Model 2 (backbone is large ~168 MB)
    try {
      debugPrint('📦 Loading Model 2 (tissue): backbone + head');
      _clipBackbone = await _open(_clipPath);
      await _breathe(); // the backbone is the long one; let a frame through
      _tissueHead = await _open(_headPath);
      debugPrint('✅ Model 2 loaded. backbone out='
          '${_clipBackbone!.getOutputTensor(0).shape} head out='
          '${_tissueHead!.getOutputTensor(0).shape}');
      _model2Loaded = true;
    } catch (e) {
      debugPrint('⚠️  Failed to load Model 2: $e');
      _model2Loaded = false;
    }

    await _breathe();

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

    // Only count as initialised if something actually loaded. Marking success
    // regardless cached a failure permanently: the service ran once before the
    // bundle had downloaded, every model failed, and it then refused to look
    // again — so a completed download did nothing until the app was restarted,
    // and the app insisted the files were missing while they sat on disk.
    _initialized = _model1Loaded || _model2Loaded || _model3Loaded;

    if (!_initialized) {
      debugPrint('ℹ️  No models loaded; will look again on the next analysis.');
    }
  }

  /// Drops the loaded interpreters so the next [init] reloads from disk.
  ///
  /// Needed when the bundle changes underneath a running app — a download
  /// finishing, or the files being deleted to reclaim space.
  void invalidate() {
    _model1?.close();
    _clipBackbone?.close();
    _tissueHead?.close();
    _infectionHead?.close();

    _model1 = _clipBackbone = _tissueHead = _infectionHead = null;
    _model1Loaded = _model2Loaded = _model3Loaded = false;
    _initialized = false;
  }

  /// Opens a model from the downloaded bundle.
  ///
  /// [assetPath] is kept as the identifier because its basename is also the
  /// name the server publishes the file under, so one constant serves both.
  ///
  /// There is no asset fallback any more: the models are no longer shipped in
  /// the APK, which is what took the download from ~285 MB to a normal size.
  /// A missing file therefore means the bundle is not installed, and saying so
  /// is the only honest answer — `init()` records the model as unavailable and
  /// [analyzeWound] refuses rather than guessing.
  Future<Interpreter> _open(String assetPath) async {
    final name = assetPath.split('/').last;

    final downloaded = await ModelRepository.I.fileFor(name);
    if (await downloaded.exists() && await downloaded.length() > 0) {
      return Interpreter.fromFile(downloaded);
    }

    throw ModelsUnavailableException(missing: name);
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
        await init();

        if (!_model1Loaded && !_model2Loaded) {
          // Both routes are shut: the server did not answer and the offline
          // files are not installed. Reporting only the connection problem
          // would send someone off to find wifi, and the analysis would still
          // fail when they did. Name both, and give the two ways out.
          throw ModelsUnavailableException(
            reason: e.retryable
                ? _NoAnalysisRoute.serverUnreachable
                : _NoAnalysisRoute.serverRefused,
            serverMessage: e.message,
          );
        }

        // Falling back to the local models is only honest while they are
        // actually on the device.
        debugPrint('⚠️  Server analysis failed (${e.message}); '
            'using the models on this device instead.');
      }
    }

    if (!_initialized) await init();

    if (kIsWeb) {
      // Web has no TFLite at all, so the simulated result is a development
      // convenience on a platform no patient uses.
      await Future.delayed(const Duration(seconds: 2));
      debugPrint('⚠️  Analysis SIMULATED (web has no TFLite).');
      return _getSimulatedResult();
    }

    if (!_model1Loaded && !_model2Loaded) {
      // On a phone this is not a simulation opportunity, it is a wound the app
      // cannot measure. It used to return 8.1 × 5.0 cm "Granulation / Normal"
      // after a two-second pause, which was unreachable only because the models
      // shipped inside the APK. With them downloaded on demand it is reachable
      // — an offline install whose download has not finished — and calling a
      // possibly necrotic wound "Normal" is the worst thing this app could do.
      throw ModelsUnavailableException();
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
      _BoxPx? woundBox; // where Model 1 found the wound; feeds Model 3's crop
      final double depth = manualDepthCm ?? 0.0;
      if (_model1Loaded) {
        final m = _runSegmentation(image, pixelsPerCm);
        length = m.lengthCm;
        width = m.widthCm;
        areaCm2 = m.areaCm2;
        woundBox = m.woundBox;
        debugPrint('✅ Model 1: L=${length.toStringAsFixed(2)}cm '
            'W=${width.toStringAsFixed(2)}cm area=${areaCm2.toStringAsFixed(2)}cm² '
            'D=${manualDepthCm == null ? "not measured" : depth.toStringAsFixed(2)}');
      }

      // --- Model 2 + Model 3: ONE CLIP backbone pass feeds both heads ---
      List<TissueFinding> tissueFindings = const [];
      String infectionStatus = 'N/A', ischaemiaStatus = 'N/A', riskBadge = 'Normal';
      double infectionProb = 0.0; // raw P(infection), for the triage bands
      if (_clipBackbone != null && (_model2Loaded || _model3Loaded)) {
        // The two heads were trained on different framings, so each is given the
        // framing it learned from: Model 2 the whole photograph, Model 3 the
        // wound crop (see [_cropForModel3]). The whole-image embedding is
        // computed lazily and shared, so the backbone still runs only once
        // whenever Model 3 is not cropped.
        List? embWhole;
        List wholeEmbedding() => embWhole ??= _clipEmbedding(image);

        if (_model2Loaded) {
          final probs = _runTissue(wholeEmbedding());
          tissueFindings = _buildTissueFindings(probs);
          debugPrint('✅ Model 2: $probs -> ${tissueFindings.summary}');
        }
        if (_model3Loaded) {
          final crop = (_cropForModel3 && woundBox != null)
              ? _woundCrop(image, woundBox)
              : null;
          if (crop != null) {
            debugPrint('🔍 Model 3 input cropped to wound: '
                '${crop.width}×${crop.height} (from ${image.width}×${image.height})');
          }
          final emb = crop == null ? wholeEmbedding() : _clipEmbedding(crop);
          final r = _runInfection(emb);
          infectionStatus = r.infection;
          ischaemiaStatus = r.ischaemia;
          riskBadge = r.badge;
          infectionProb = r.pInfection;
          debugPrint('✅ Model 3: badge=$riskBadge '
              'infection=$infectionStatus ischaemia=$ischaemiaStatus');
        }
      }

      return AnalysisResult(
        length: length,
        width: width,
        area: areaCm2, // segmented wound area (pixel count × scale²)
        depth: depth, // clinician-entered probe depth; 0 = not measured
        tissueFindings: tissueFindings,
        pusLevel: 'N/A', // legacy field — superseded by Model 3 infection/ischaemia
        inflammation: 'N/A', // legacy field — superseded by Model 3
        infection: infectionStatus,
        ischaemia: ischaemiaStatus,
        riskBadge: riskBadge,
        infectionProbability: infectionProb,
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

    // 3) Erase any region that is the printed calibration label, so it can
    //    neither be measured nor merged into a wound beside it.
    if (_refusePrintedLabel) {
      final removed = _erasePrintedLabels(mask, resized);
      if (removed > 0) {
        debugPrint('🏷️  Refused $removed blob(s) sitting on the calibration label');
      }
    }

    // 4) Measure the largest connected region only (= largest contour).
    final comp = _largestComponent(mask);
    if (comp == null) return const _Measurements(0, 0, 0); // no wound found

    // 5) TRUE length/width via the wound's principal (PCA) axes — equivalent to
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
      // Mask-space box -> original-image pixels, rounded outwards so the crop
      // never clips wound edge pixels.
      woundBox: _BoxPx(
        (comp.minX * sx).floor(),
        (comp.minY * sy).floor(),
        (comp.maxX * sx).ceil(),
        (comp.maxY * sy).ceil(),
      ),
    );
  }

  /// Square crop centred on the wound, padded by [_model3CropPadding].
  ///
  /// Square on purpose: [_clipPreprocess] resizes the shorter side to 224 and
  /// then centre-crops 224×224. Handing it a non-square crop would let that
  /// centre-crop cut the wound edges off again — the very failure this fixes.
  img.Image _woundCrop(img.Image src, _BoxPx box) {
    final shortest = min(src.width, src.height);
    if (shortest < 16) return src; // degenerate image; nothing sensible to crop

    final bw = (box.maxX - box.minX).toDouble();
    final bh = (box.maxY - box.minY).toDouble();
    final cx = (box.minX + box.maxX) / 2.0;
    final cy = (box.minY + box.maxY) / 2.0;

    final side = (max(bw, bh) * (1 + 2 * _model3CropPadding))
        .clamp(16.0, shortest.toDouble());
    final sideI = side.round();

    final x0 = (cx - side / 2).round().clamp(0, src.width - sideI).toInt();
    final y0 = (cy - side / 2).round().clamp(0, src.height - sideI).toInt();

    return img.copyCrop(src, x: x0, y: y0, width: sideI, height: sideI);
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

  /// Clear every region of [mask] that is the printed calibration label, and
  /// return how many were cleared.
  ///
  /// Erasing the pixels rather than skipping the region is deliberate: it keeps
  /// the visible part of a wound the sticker happens to be touching, instead of
  /// discarding wound and label together. (In 153 clinic photographs the two
  /// never actually fused into one region, so the two rules scored identically
  /// there — this is the one that degrades better when they do.)
  ///
  /// [resized] is the model-input image, so mask coordinates index it directly.
  int _erasePrintedLabels(List<List<bool>> mask, img.Image resized) {
    final h = mask.length, w = mask[0].length;
    final ids = List.generate(h, (_) => List.filled(w, 0));
    final boxes = <List<int>>[]; // [minX, minY, maxX, maxY, area] per region

    for (int y0 = 0; y0 < h; y0++) {
      for (int x0 = 0; x0 < w; x0++) {
        if (!mask[y0][x0] || ids[y0][x0] != 0) continue;
        final id = boxes.length + 1;
        int area = 0, minX = x0, maxX = x0, minY = y0, maxY = y0;
        final stack = <int>[y0 * w + x0];
        ids[y0][x0] = id;
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
              if (mask[ny][nx] && ids[ny][nx] == 0) {
                ids[ny][nx] = id;
                stack.add(ny * w + nx);
              }
            }
          }
        }
        boxes.add([minX, minY, maxX, maxY, area]);
      }
    }

    var cleared = 0;
    for (int i = 0; i < boxes.length; i++) {
      if (!_isPrintedLabel(resized, ids, i + 1, boxes[i])) continue;
      final b = boxes[i];
      for (int y = b[1]; y <= b[3]; y++) {
        for (int x = b[0]; x <= b[2]; x++) {
          if (ids[y][x] == i + 1) mask[y][x] = false;
        }
      }
      cleared++;
    }
    return cleared;
  }

  bool _isPrintedLabel(
          img.Image src, List<List<int>> ids, int id, List<int> box) =>
      isPrintedLabelRegion(
        ids: ids,
        id: id,
        box: box,
        isPaper: (x, y) {
          final p = src.getPixel(x, y);
          final rr = p.rNormalized, gg = p.gNormalized, bb = p.bNormalized;
          final v = max(rr, max(gg, bb));
          final s = v <= 0 ? 0.0 : (v - min(rr, min(gg, bb))) / v;
          return s < _paperMaxSat && v > _paperMinVal;
        },
        whiteSurround: _labelWhiteSurround,
      );

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
      // Kept alongside the binary string: the triage bands this number rather
      // than applying one cut-off, and the string cannot express "unsure".
      pInfection: pInfection,
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
      area: 26.0,
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

  /// Raw P(infection) = p[infection] + p[both], before any threshold.
  final double pInfection;

  const _InfectionResult({
    required this.infection,
    required this.ischaemia,
    required this.badge,
    this.pInfection = 0.0,
  });
}

class _Measurements {
  final double lengthCm;
  final double widthCm;
  final double areaCm2;

  /// Wound bounding box in ORIGINAL-image pixels; null when no wound was found.
  /// Model 3 crops to this so its input matches the tight wound patches it was
  /// trained on — see [AiService._woundCrop].
  final _BoxPx? woundBox;

  const _Measurements(this.lengthCm, this.widthCm, this.areaCm2,
      {this.woundBox});
}

/// Axis-aligned box in original-image pixel space.
class _BoxPx {
  final int minX, minY, maxX, maxY;
  const _BoxPx(this.minX, this.minY, this.maxX, this.maxY);
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

/// Why no analysis route was available.
enum _NoAnalysisRoute {
  /// Offline mode, or nothing was tried remotely: only the files are missing.
  filesOnly,

  /// Online mode, and the server could not be reached — a dropped connection,
  /// a timeout, a server that is down.
  serverUnreachable,

  /// Online mode, and the server answered but declined — signed out, or a
  /// photo it could not use. Trying again unchanged will not help.
  serverRefused,
}

/// The wound could not be analysed, by any available route.
///
/// Raised instead of inventing a measurement. The message names every reason
/// that applies and the way out of each: someone told only "no connection"
/// will go and find wifi, and still be unable to analyse when they get there,
/// because the offline files were never downloaded either.
class ModelsUnavailableException implements AnalysisException {
  /// The first file found missing, when one was identified. Useful in logs;
  /// never shown to the patient, who cannot act on a filename.
  final String? missing;

  final _NoAnalysisRoute reason;

  /// What the server said, kept for the log rather than the screen.
  final String? serverMessage;

  ModelsUnavailableException({
    this.missing,
    this.reason = _NoAnalysisRoute.filesOnly,
    this.serverMessage,
  });

  @override
  String get message {
    switch (reason) {
      case _NoAnalysisRoute.serverUnreachable:
        return 'analysis_no_route_offline'.tr();
      case _NoAnalysisRoute.serverRefused:
        return 'analysis_no_route_refused'.tr();
      case _NoAnalysisRoute.filesOnly:
        return 'analysis_models_missing'.tr();
    }
  }

  /// Always: a download or a connection is a thing the participant can go and
  /// fix, unlike a photo the model cannot read.
  @override
  bool get retryable => true;

  @override
  String toString() => 'ModelsUnavailableException(reason: $reason, '
      'missing: ${missing ?? "all"}, server: ${serverMessage ?? "-"})';
}
