class WoundEntry {
  final int? id; // Database ID
  final DateTime date;
  final String imagePath;     // asset or file path
  final double lengthCm;
  final double widthCm;
  final double? depthCm;      // Depth measurement
  final String inflammation;  // None / Mild / ...
  final double progressPct;   // +12 etc.

  const WoundEntry({
    this.id,
    required this.date,
    required this.imagePath,
    required this.lengthCm,
    required this.widthCm,
    this.depthCm,
    required this.inflammation,
    required this.progressPct,
  });
}
