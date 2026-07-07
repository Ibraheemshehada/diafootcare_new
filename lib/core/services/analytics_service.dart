import 'package:easy_localization/easy_localization.dart';

import '../../data/repositories/analytics_repository.dart';

/// Fire-and-forget local usage logging for the study's engagement metrics.
/// Nothing is sent off-device — events go to the local `analytics_events` table.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService I = AnalyticsService._();

  final AnalyticsRepository _repo = AnalyticsRepository();

  /// Log one app launch (usage frequency / retention).
  void logAppOpen() {
    _repo.log('app_open');
  }

  /// Log opening a feature, identified by its route (feature utilization).
  void logFeature(String route) {
    _repo.log('feature_open', route);
  }
}

/// Human-readable, localized label for a feature route (used by the usage
/// screen and the export). Falls back to the raw route for anything unmapped.
String analyticsFeatureLabel(String route) {
  switch (route) {
    case '/capture':
      return 'capture_wound'.tr();
    case '/WoundHistoryScreen':
      return 'log_measurements'.tr();
    case '/reminders':
      return 'daily_reminders'.tr();
    case '/notes':
      return 'daily_notes'.tr();
    case '/glucose':
      return 'glucose_title'.tr();
    case '/medication':
      return 'medication_title'.tr();
    case '/selfcare':
      return 'selfcare_title'.tr();
    case '/appointments':
      return 'appt_title'.tr();
    case '/wellbeing':
      return 'wellbeing_title'.tr();
    case '/education':
      return 'edu_title'.tr();
    default:
      return route;
  }
}
