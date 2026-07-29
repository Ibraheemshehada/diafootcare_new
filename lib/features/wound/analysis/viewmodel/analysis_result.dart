import 'tissue_finding.dart';

export 'tissue_finding.dart';

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
  final double healingProgress;
  final String graphImagePath; // optional placeholder for now
  final bool isFromModel; // Indicates if measurements are from Model 1 or simulated
  final bool isCalibrated; // true if cm came from a real reference-object scale

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
    required this.healingProgress,
    this.graphImagePath = 'assets/images/progress_graph.png',
    this.isFromModel = false,
    this.isCalibrated = false,
    this.analysedOn = 'offline',
    String? tissueType,
  }) : _legacyTissueType = tissueType;

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
}
