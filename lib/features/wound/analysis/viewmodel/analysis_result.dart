import 'package:easy_localization/easy_localization.dart';
import 'tissue_finding.dart';

export 'tissue_finding.dart';

/// How square the camera was to the wound, banded by measured error.
enum CaptureAngle { good, marginal, poor, unknown }

class AnalysisResult {
  final double length;
  final double width;
  final double depth;

  /// Wound surface area in cm². From Model 1 this is the segmented-pixel count
  /// scaled to cm² (the true wound area, smaller than length × width, which is
  /// the bounding rectangle). Reconstructed records fall back to length × width.
  final double area;

  /// Every tissue class the model considered, with its probability and the
  /// threshold it was judged against.
  ///
  /// Replaces a single `tissueType` string. The head is multi-label — a wound
  /// bed holds several tissue types at once — so naming one winner discarded
  /// most of the answer and made the label unstable: whichever of two near-tied
  /// classes scored a hundredth higher won, and that differed between the phone
  /// and the server for the same photograph.
  final List<TissueFinding> tissueFindings;

  final String pusLevel; // legacy field kept for DB/history back-compat
  final String inflammation; // legacy field kept for DB/history back-compat
  // Model 3 (infection & ischaemia) — replaces the old "Pus Level" output.
  final String infection; // 'Present' / 'Not Present'
  final String ischaemia; // 'Impaired' / 'Adequate'
  final String riskBadge; // 'Normal' / 'Infection Detected' / 'Impaired Blood Flow' / 'High Risk'

  /// Raw P(infection) from the Model 3 head — `p[infection] + p[both]`.
  ///
  /// The binary [infection] string throws this away, but the triage in
  /// `infection_triage.dart` needs the number: it bands the score into
  /// low/uncertain/high rather than forcing one cut-off, and a single
  /// threshold cannot express "we are not sure". Defaults to 0 for records
  /// written before this existed and for results that came from the server
  /// without it.
  final double infectionProbability;
  final double healingProgress;
  final String graphImagePath; // optional placeholder for now
  final bool isFromModel; // Indicates if measurements are from Model 1 or simulated
  final bool isCalibrated; // true if cm came from a real reference-object scale

  /// True scale from the printed calibration ring, in ORIGINAL-image pixels per
  /// centimetre, or null when no ring was found.
  ///
  /// This is what makes a centimetre mean anything. Without it the app divided
  /// the frame's wider side by an assumed 12 cm, so the number moved with how
  /// far the phone happened to be held — a real 1.4 cm wound was reported as
  /// 0.9 cm for that reason alone.
  final double? pixelsPerCm;

  /// How far the label plane was turned from the camera, in degrees.
  ///
  /// Kept with the result because it is the single best predictor of a bad
  /// measurement: across 26 clinic photographs error correlates with tilt at
  /// r = +0.479, averaging 18% below 30° and 56% above 40°. A wound extent lying
  /// along the tilt is compressed by cos θ — −23% at 40°.
  final double? tiltDeg;

  /// Which printed label was used: the 15 mm small one, or the 20 mm standard.
  final bool? usedSmallLabel;

  /// The photograph with the measured region drawn on it.
  ///
  /// A number with nothing behind it cannot be checked: a clinician had no way
  /// to tell a correct measurement from one taken off the printed label, which
  /// happened in 16 of 42 small-label photographs. Every wrong conclusion in
  /// this project was caught by looking at the mask rather than the figure.
  final String? overlayImagePath;

  /// Where the analysis actually ran: 'online' (server) or 'offline' (phone).
  ///
  /// Recorded per result rather than read from the current mode at sync time,
  /// because a participant can change mode between capturing and syncing, and
  /// the study needs to know which pipeline produced each number.
  final String analysedOn;

  /// Set only when the result came from a stored record written before
  /// per-class findings existed, or from a caller still passing a bare label.
  final String? _legacyTissueType;

  AnalysisResult({
    required this.length,
    required this.width,
    required this.depth,
    this.area = 0.0,
    this.tissueFindings = const [],
    required this.pusLevel,
    required this.inflammation,
    this.infection = 'N/A',
    this.ischaemia = 'N/A',
    this.riskBadge = 'Normal',
    this.infectionProbability = 0.0,
    required this.healingProgress,
    this.graphImagePath = 'assets/images/progress_graph.png',
    this.isFromModel = false,
    this.isCalibrated = false,
    this.pixelsPerCm,
    this.tiltDeg,
    this.usedSmallLabel,
    this.overlayImagePath,
    this.analysedOn = 'offline',
    String? tissueType,
  }) : _legacyTissueType = tissueType;

  /// Whether the photograph was taken square enough to the wound to trust.
  ///
  /// Thresholds are the measured ones, not round numbers: below 30° error
  /// averages 18%, between 30° and 40° it is 40%, above 40° it is 56%.
  CaptureAngle get captureAngle {
    final t = tiltDeg;
    if (t == null) return CaptureAngle.unknown;
    if (t <= 30) return CaptureAngle.good;
    if (t <= 40) return CaptureAngle.marginal;
    return CaptureAngle.poor;
  }

  /// The single tissue label, for the places that can show only one.
  ///
  /// The most clinically serious class present — see [TissueFindings.primaryType].
  String get primaryTissueType {
    if (tissueFindings.isNotEmpty) return tissueFindings.primaryType;
    return _legacyTissueType ?? 'Unknown';
  }

  /// Kept so existing callers and records written before this change keep
  /// working while the UI migrates to showing every finding.
  String get tissueType => primaryTissueType;

  /// Every present class, most serious first — "Necrosis, Slough, Callus".
  String get tissueSummary =>
      tissueFindings.isNotEmpty ? tissueFindings.summary : primaryTissueType;

  /// [tissueSummary] in the app's current language — for screens only, never
  /// for storage or sync (see [TissueFinding.displayName]).
  String get localizedTissueSummary {
    if (tissueFindings.isNotEmpty) return tissueFindings.localizedSummary;
    final legacy = primaryTissueType;
    final key = 'tissue_${legacy.toLowerCase()}';
    final t = key.tr();
    return t == key ? legacy : t;
  }
}
