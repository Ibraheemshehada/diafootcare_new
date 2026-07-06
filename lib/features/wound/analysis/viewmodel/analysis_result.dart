class AnalysisResult {
  final double length;
  final double width;
  final double depth;
  final String tissueType;
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

  AnalysisResult({
    required this.length,
    required this.width,
    required this.depth,
    required this.tissueType,
    required this.pusLevel,
    required this.inflammation,
    this.infection = 'N/A',
    this.ischaemia = 'N/A',
    this.riskBadge = 'Normal',
    required this.healingProgress,
    this.graphImagePath = 'assets/images/progress_graph.png',
    this.isFromModel = false,
    this.isCalibrated = false,
  });
}
