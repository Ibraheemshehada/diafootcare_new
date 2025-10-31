class WoundEntry {
  final DateTime date;
  final String imagePath;     // asset or file path
  final double lengthCm;
  final double widthCm;
  final String inflammation;  // None / Mild / ...
  final double progressPct;   // +12 etc.

  const WoundEntry({
    required this.date,
    required this.imagePath,
    required this.lengthCm,
    required this.widthCm,
    required this.inflammation,
    required this.progressPct,
  });
}
