class AnalysisResult {
  final double length;
  final double width;
  final double depth;
  final String tissueType;
  final String pusLevel;
  final String inflammation;
  final double healingProgress;
  final String graphImagePath; // optional placeholder for now

  AnalysisResult({
    required this.length,
    required this.width,
    required this.depth,
    required this.tissueType,
    required this.pusLevel,
    required this.inflammation,
    required this.healingProgress,
    this.graphImagePath = 'assets/images/progress_graph.png',
  });
}
