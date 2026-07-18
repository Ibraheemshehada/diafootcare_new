import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'sync_service.dart';

/// Background upload, so records reach the study without the patient having to
/// open the app.
///
/// Everything here runs in a **separate isolate** with no access to anything the
/// UI isolate set up. State is not shared: the database, the secure-storage
/// token and the HTTP client are all re-created from scratch inside
/// [backgroundSyncDispatcher]. That is why the sync path is built from
/// singletons that can be constructed cold rather than objects handed down from
/// widgets.
class BackgroundSync {
  BackgroundSync._();

  static const taskName = 'dfc-sync';
  static const _uniqueName = 'dfc-periodic-sync';

  /// Android's WorkManager will not run a periodic task more often than this,
  /// whatever is requested — asking for less just gets silently clamped.
  static const _frequency = Duration(minutes: 15);

  static Future<void> register() async {
    // iOS background execution is opportunistic and cannot be relied on for
    // clinical data; Android is the platform this actually works on. Keeping it
    // Android-only avoids implying a guarantee iOS does not make.
    if (defaultTargetPlatform != TargetPlatform.android) return;

    try {
      await Workmanager().initialize(backgroundSyncDispatcher);

      await Workmanager().registerPeriodicTask(
        _uniqueName,
        taskName,
        frequency: _frequency,
        // Replace rather than keep: re-registering on every launch would
        // otherwise accumulate duplicate schedules.
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        constraints: Constraints(
          // No point waking up without a connection, and never on a device
          // that is nearly flat — a patient's phone dying is worse than data
          // arriving fifteen minutes later.
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 1),
      );

      debugPrint('🔄 Background sync registered (every ${_frequency.inMinutes}m)');
    } catch (e) {
      // A scheduling failure must not stop the app launching; in-app sync still
      // covers everything while the app is open.
      debugPrint('🔄 Could not register background sync: $e');
    }
  }

  static Future<void> cancel() async {
    try {
      await Workmanager().cancelByUniqueName(_uniqueName);
    } catch (_) {}
  }
}

/// Entry point for the background isolate.
///
/// Must be top-level and annotated, or the tree-shaker removes it from the
/// release build and the task silently never runs.
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // The background isolate has no binding yet; plugin channels (secure
    // storage, sqflite, connectivity) all need one.
    WidgetsFlutterBinding.ensureInitialized();

    if (task != BackgroundSync.taskName) return true;

    try {
      final result = await SyncService.I.syncNow();
      debugPrint('🔄 Background sync: '
          'uploaded=${result.uploaded} failed=${result.failed}'
          '${result.skipped ? " (skipped: ${result.reason})" : ""}');

      // Returning false asks WorkManager to retry with backoff. Only genuine
      // failures should do that — "offline" or "not signed in" are normal
      // states, and retrying them just burns wakeups.
      return result.failed == 0;
    } catch (e) {
      debugPrint('🔄 Background sync threw: $e');
      return false;
    }
  });
}
