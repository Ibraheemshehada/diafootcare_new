/// Number of times a feature (identified by its route) was opened.
class FeatureCount {
  final String route;
  final int count;
  const FeatureCount(this.route, this.count);
}

/// Time-on-task for one screen: how many times it was opened and the total
/// milliseconds spent on it (summed dwell time between push and pop).
class ScreenTime {
  final String route;
  final int opens;
  final int totalMs;
  const ScreenTime(this.route, this.opens, this.totalMs);

  /// Mean dwell time per visit, in milliseconds.
  int get avgMs => opens == 0 ? 0 : (totalMs / opens).round();
}

/// Aggregated engagement/usage metrics for the study and the "My Activity" screen.
class AnalyticsSummary {
  final int appOpens;
  final int activeDays; // distinct calendar days with any activity
  final int currentStreak; // consecutive active days ending today/yesterday
  final DateTime? firstUse;
  final DateTime? lastActive;
  final List<FeatureCount> features; // sorted by count desc

  // ---- Usability-study metrics ----
  /// Uncaught/handled errors recorded locally.
  final int errorCount;

  /// Opens of help/tutorial content (capture tips, senior tips, education).
  final int helpOpens;

  /// A "task" is a multi-step flow (e.g. add a glucose reading). Started when
  /// the flow opens, completed when it saves successfully.
  final int taskStarts;
  final int taskCompletes;

  /// Time-on-task per screen, longest total first.
  final List<ScreenTime> screenTimes;

  const AnalyticsSummary({
    required this.appOpens,
    required this.activeDays,
    required this.currentStreak,
    required this.firstUse,
    required this.lastActive,
    required this.features,
    this.errorCount = 0,
    this.helpOpens = 0,
    this.taskStarts = 0,
    this.taskCompletes = 0,
    this.screenTimes = const [],
  });

  /// Task completion rate 0..1, or null when no task was ever started.
  double? get taskCompletionRate =>
      taskStarts == 0 ? null : (taskCompletes / taskStarts).clamp(0.0, 1.0);

  bool get isEmpty => appOpens == 0 && activeDays == 0 && features.isEmpty;

  static const AnalyticsSummary empty = AnalyticsSummary(
    appOpens: 0,
    activeDays: 0,
    currentStreak: 0,
    firstUse: null,
    lastActive: null,
    features: [],
  );
}
