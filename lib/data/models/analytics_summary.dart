/// Number of times a feature (identified by its route) was opened.
class FeatureCount {
  final String route;
  final int count;
  const FeatureCount(this.route, this.count);
}

/// Aggregated engagement/usage metrics for the study and the "My Activity" screen.
class AnalyticsSummary {
  final int appOpens;
  final int activeDays; // distinct calendar days with any activity
  final int currentStreak; // consecutive active days ending today/yesterday
  final DateTime? firstUse;
  final DateTime? lastActive;
  final List<FeatureCount> features; // sorted by count desc

  const AnalyticsSummary({
    required this.appOpens,
    required this.activeDays,
    required this.currentStreak,
    required this.firstUse,
    required this.lastActive,
    required this.features,
  });

  bool get isEmpty =>
      appOpens == 0 && activeDays == 0 && features.isEmpty;

  static const AnalyticsSummary empty = AnalyticsSummary(
    appOpens: 0,
    activeDays: 0,
    currentStreak: 0,
    firstUse: null,
    lastActive: null,
    features: [],
  );
}
