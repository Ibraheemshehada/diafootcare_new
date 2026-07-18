import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

  /// Navigation log: a screen/route was pushed.
  void logScreenOpen(String route) {
    _repo.log('screen_open', route);
  }

  /// Time-on-task: a screen was popped after [dwell] on it.
  void logScreenClose(String route, Duration dwell) {
    _repo.log('screen_close', route, dwell.inMilliseconds);
  }

  /// An error surfaced to the user or caught by the global handler.
  /// Only the message is stored — never shown to the user.
  void logError(String message) {
    // Keep the stored payload bounded; stack traces can be huge.
    final trimmed =
        message.length > 300 ? '${message.substring(0, 300)}…' : message;
    _repo.log('error', trimmed);
  }

  /// Help / tutorial content was opened (capture tips, senior tips, education).
  void logHelp(String name) {
    _repo.log('help_open', name);
  }

  /// A multi-step task flow was started (e.g. the "add glucose" dialog opened).
  void logTaskStart(String task) {
    _repo.log('task_start', task);
  }

  /// A task flow completed successfully (the record was saved).
  void logTaskComplete(String task) {
    _repo.log('task_complete', task);
  }
}

/// Logs every route push/pop so the study gets **navigation logs** and
/// **time-on-task** without instrumenting each screen by hand.
class AnalyticsRouteObserver extends NavigatorObserver {
  final Map<Route<dynamic>, DateTime> _openedAt = {};

  /// A stable label for a route.
  ///
  /// Named routes use their name. For a route pushed without one, the builder's
  /// runtimeType is the only clue available, but it stringifies as
  /// `(BuildContext) => ConsentScreen` — which the study then groups by
  /// verbatim. Worse, that string is not guaranteed stable across builds, so a
  /// release build could silently split one screen into several labels.
  ///
  /// The screen name is extracted from it, and anything that does not look like
  /// a plain identifier falls back to a single bucket rather than polluting the
  /// data with one label per build.
  static final _returnType = RegExp(r'=>\s*([A-Za-z_][A-Za-z0-9_]*)');

  /// Turns a builder's runtimeType string into a stable label.
  ///
  /// Exposed for testing: the study groups by this value, so a change in how it
  /// is derived silently reshapes the data and is worth a test rather than an
  /// eyeball on a device.
  @visibleForTesting
  static String labelForBuilderType(String rawRuntimeType) {
    final match = _returnType.firstMatch(rawRuntimeType);
    return match != null ? '(unnamed) ${match.group(1)}' : '(unnamed)';
  }

  String? _name(Route<dynamic>? route) {
    final n = route?.settings.name;
    if (n != null && n.isNotEmpty) return n;

    if (route is MaterialPageRoute) {
      return labelForBuilderType(route.builder.runtimeType.toString());
    }

    return null;
  }

  void _open(Route<dynamic> route) {
    final n = _name(route);
    if (n == null) return;
    _openedAt[route] = DateTime.now();
    AnalyticsService.I.logScreenOpen(n);
  }

  void _close(Route<dynamic> route) {
    final n = _name(route);
    final since = _openedAt.remove(route);
    if (n == null || since == null) return;
    AnalyticsService.I.logScreenClose(n, DateTime.now().difference(since));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _open(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _close(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _close(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _close(oldRoute);
    if (newRoute != null) _open(newRoute);
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
    case '/usage':
      return 'usage_title'.tr();
    case '/education/article':
      return '${'edu_title'.tr()} — ${'edu_articles'.tr()}';
    case '/appointments/add':
      return 'appt_add'.tr();
    case '/wellbeing/qol-checkin':
      return 'wellbeing_new_checkin'.tr();
    case '/wellbeing/satisfaction':
      return 'satisfaction_title'.tr();
    case '/wellbeing/sus':
      return 'sus_title'.tr();
    default:
      return route;
  }
}
