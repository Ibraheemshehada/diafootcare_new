import 'dart:convert';
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/database_helper.dart';
import '../../data/repositories/engagement_rollup_repository.dart';
import '../network/api_client.dart';
import 'device_service.dart';

/// How one local table maps onto an API endpoint.
class _SyncSpec {
  final String table;

  /// `null` means the dedicated wound-scan endpoint rather than `/sync/{type}`.
  final String? type;

  /// Builds the request body for one row.
  final Map<String, dynamic> Function(Map<String, Object?> row) map;

  /// Extra SQL predicate, for tables where only some rows are uploaded.
  final String? where;

  const _SyncSpec(this.table, this.type, this.map, {this.where});

  String get endpoint => type == null ? '/wound-scans/sync' : '/sync/$type';
}

/// Result of one sync pass.
class SyncResult {
  final int uploaded;
  final int failed;
  final bool skipped;
  final String? reason;

  const SyncResult({
    this.uploaded = 0,
    this.failed = 0,
    this.skipped = false,
    this.reason,
  });

  bool get didWork => uploaded > 0 || failed > 0;
}

/// Uploads locally-recorded records once the device is online.
///
/// The app is offline-first: everything is written to SQLite immediately with
/// `pending_sync = 1`, regardless of connectivity, and this service drains that
/// queue in the background. Nothing here is ever on the path of saving a record,
/// so a network failure can never cost a patient their data.
class SyncService {
  SyncService._();
  static final SyncService I = SyncService._();

  static const _batchSize = 50;
  static const _uuid = Uuid();

  final _helper = DatabaseHelper();
  final _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _periodic;
  bool _running = false;
  bool _rateLimited = false;
  int _backoffStep = 0;
  Timer? _retryTimer;

  /// Exposed so the UI can show how much is still waiting.
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);
  final ValueNotifier<bool> syncing = ValueNotifier<bool>(false);

  /// Retry schedule after a failure. Deliberately widening: a flapping
  /// connection must not turn into a request every few seconds, which drains
  /// the battery and hammers the server for no benefit.
  static const _backoff = [
    Duration(seconds: 1),
    Duration(seconds: 5),
    Duration(seconds: 30),
    Duration(minutes: 2),
    Duration(minutes: 10),
  ];

  List<_SyncSpec> get _specs => [
        // Wound scans: the app stores tissue/infection as display strings, so
        // they are normalised to the booleans and probabilities the API expects.
        _SyncSpec('wounds', null, (r) {
          final length = (r['length'] as num?)?.toDouble() ?? 0;
          final width = (r['width'] as num?)?.toDouble() ?? 0;
          return {
            'captured_at': _iso(r['createdAt']) ?? '${r['date']}T00:00:00Z',
            'length_cm': length,
            'width_cm': width,
            // The app records length/width; area is derived here rather than
            // stored twice and risking the two disagreeing.
            'area_cm2': double.parse((length * width * 0.785).toStringAsFixed(2)),
            'depth_cm': (r['depth'] as num?)?.toDouble(),
            // The server's tissue_json column was always meant to hold the
            // per-class answer; it only ever received the headline. Both go up
            // now, so the dashboard can show what the model actually found.
            'tissue_json': _tissueJson(r),
            'infection_present': _yesNo(r['infection']),
            'ischaemia_present': _yesNo(r['ischaemia']),
            'risk_badge': _risk(r['infection'], r['ischaemia']),
            'source': 'offline',
          };
        }),
        _SyncSpec('glucose_readings', 'glucose', (r) => {
              'value_mgdl': (r['value'] as num?)?.toDouble() ?? 0,
              'tag': r['tag'],
              'measured_at': _iso(r['dateTime']),
            }),
        _SyncSpec('self_care_logs', 'self-care', (r) => {
              'item_key': r['itemKey'],
              'log_date': _dateKeyToIso(r['dateKey'] as String?),
              'done_at': _iso(r['doneAt']),
            }),
        _SyncSpec('qol_entries', 'qol', (r) => {
              'pain': r['pain'] ?? 0,
              'mobility': r['mobility'] ?? 0,
              'emotional': r['emotional'] ?? 0,
              'recorded_at': _iso(r['dateTime']),
            }),
        _SyncSpec('satisfaction_entries', 'satisfaction', (r) => {
              'ease_of_use': r['ease'] ?? 3,
              'usefulness': r['usefulness'] ?? 3,
              // Local column is `willingness`; the API calls it would_continue.
              'would_continue': r['willingness'] ?? 3,
              'recorded_at': _iso(r['dateTime']),
            }),
        _SyncSpec('appointments', 'appointments', (r) => {
              'title': r['title'],
              'scheduled_at': _iso(r['dateTime']),
              'location': r['location'],
              'notes': r['notes'],
            }),
        _SyncSpec('medications', 'medications', (r) => {
              'name': r['name'],
              'dosage': r['dosage'],
              'times_per_day': r['timesPerDay'] ?? 1,
              'is_active': true,
            }),
        // Dose logs carry the medication's local_uuid so the server can join
        // them even when they arrive before the medication row itself.
        _SyncSpec('medication_logs', 'medication-logs', (r) => {
              'medication_local_uuid': r['medication_local_uuid'],
              'log_date': _dateKeyToIso(r['dateKey'] as String?),
              'dose_index': r['doseIndex'] ?? 0,
              'taken': true,
            }),
        _SyncSpec('sus_responses', 'sus', (r) => {
              for (var i = 1; i <= 10; i++) 'q$i': r['q$i'] ?? 3,
              'recorded_at': _iso(r['dateTime']),
              'consent_version': r['consent_version'],
            }),
        // Only the low-volume, analytically rich events go up raw. The
        // high-volume ones (screen opens and the like) are rolled up daily —
        // see EngagementRollupRepository for why aggregating beats sampling.
        _SyncSpec(
          'analytics_events',
          'engagement',
          (r) => {
            // Local `type` is the event; local `name` is what it acted on. The
            // API names those `name` and `target`.
            'name': r['type'],
            'target': r['name'],
            'value': r['value'],
            'occurred_at': _iso(r['ts']),
          },
          where: "type IN ('app_open','task_start','task_complete','error')",
        ),
        _SyncSpec('engagement_daily', 'engagement-daily', (r) => {
              'day': r['day'],
              'name': r['name'],
              'target': r['target'],
              'event_count': r['event_count'] ?? 0,
              'total_value': r['total_value'],
            }),
        _SyncSpec('consents', 'consents', (r) => {
              'version': r['version'] ?? 0,
              'accepted_at': _iso(r['accepted_at']),
              'locale': r['locale'],
              'covers_prior': (r['covers_prior'] as int?) == 1,
            }),
      ];

  // ---------- lifecycle ----------

  /// Starts watching connectivity. Safe to call more than once.
  Future<void> start() async {
    await refreshPendingCount();

    _sub ??= _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) {
        debugPrint('🔄 Connectivity returned — draining sync queue');
        // Reset the backoff: this is a new network, not another failure.
        _backoffStep = 0;
        unawaited(syncNow());
      }
    });

    // Records created during a session would otherwise wait for the next launch
    // or connectivity change. A quiet periodic drain keeps the queue short
    // without being a poll loop.
    _periodic ??= Timer.periodic(const Duration(minutes: 15), (_) {
      if (pendingCount.value > 0) unawaited(syncNow());
    });

    unawaited(syncNow());
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _periodic?.cancel();
    _periodic = null;
    _retryTimer?.cancel();
  }

  /// Drains the queue when the app goes to the background.
  ///
  /// This is the moment a session's records are complete, and the point at which
  /// the user is least likely to notice the work.
  Future<void> onAppPaused() => syncNow();

  // ---------- the queue ----------

  Future<int> refreshPendingCount() async {
    final db = await _helper.database;
    var total = 0;

    for (final spec in _specs) {
      try {
        final predicate = spec.where == null ? '' : ' AND ${spec.where}';
        final rows = await db.rawQuery(
            'SELECT COUNT(*) AS c FROM ${spec.table} WHERE pending_sync = 1$predicate');
        total += (rows.first['c'] as int?) ?? 0;
      } catch (_) {
        // A table that does not exist on this install simply has nothing queued.
      }
    }

    pendingCount.value = total;
    return total;
  }

  /// Drains the queue once.
  ///
  /// Returns without doing anything when there is no session or no connection —
  /// both are normal states for this app, not errors.
  Future<SyncResult> syncNow() async {
    if (_running) return const SyncResult(skipped: true, reason: 'already running');
    if (!await ApiClient.I.hasToken) {
      return const SyncResult(skipped: true, reason: 'not signed in');
    }

    final conn = await _connectivity.checkConnectivity();
    if (conn.every((r) => r == ConnectivityResult.none)) {
      return const SyncResult(skipped: true, reason: 'offline');
    }

    _running = true;
    syncing.value = true;

    var uploaded = 0;
    var failed = 0;

    try {
      // Refresh the rollups first so the current day's counts are up to date
      // before they are uploaded.
      await EngagementRollupRepository().rebuild();

      final deviceUuid = await DeviceService.I.deviceUuid();
      final db = await _helper.database;

      for (final spec in _specs) {
        final result = await _syncTable(db, spec, deviceUuid);
        uploaded += result.uploaded;
        failed += result.failed;
      }

      if (_rateLimited) {
        // Jump most of the way up the backoff ladder rather than starting at 1s.
        _backoffStep = _backoff.length - 2;
        _rateLimited = false;
        _scheduleRetry();
      } else if (failed > 0) {
        _scheduleRetry();
      } else {
        _backoffStep = 0;
      }
    } catch (e) {
      debugPrint('🔄 Sync pass failed: $e');
      _scheduleRetry();
    } finally {
      _running = false;
      syncing.value = false;
      await refreshPendingCount();
    }

    return SyncResult(uploaded: uploaded, failed: failed);
  }

  Future<SyncResult> _syncTable(Database db, _SyncSpec spec, String deviceUuid) async {
    var uploaded = 0;
    var failed = 0;

    while (true) {
      List<Map<String, Object?>> rows;
      try {
        // `rowid` must be selected explicitly. db.query() returns only the
        // declared columns, so the fallback below silently updated nothing when
        // a row had no local_uuid — the id was never persisted, every pass sent
        // a fresh one, and the server saw each attempt as a new record. That
        // turned 53 real events into 38,000 rows and left the queue permanently
        // "pending" because the acknowledged uuid matched no local row.
        final predicate = spec.where == null ? '' : ' AND ${spec.where}';
        rows = await db.rawQuery(
          'SELECT rowid AS _rowid, * FROM ${spec.table} '
          'WHERE pending_sync = 1$predicate LIMIT $_batchSize',
        );
      } catch (_) {
        return const SyncResult(); // table absent on this install
      }

      if (rows.isEmpty) break;

      // Dose logs reference a medication by its local row id, but the server
      // joins on the medication's local_uuid. Resolve that here rather than in
      // the mapper, which is synchronous and cannot query.
      Map<String, String> medicationUuids = const {};
      if (spec.table == 'medication_logs') {
        final meds = await db.query('medications', columns: ['id', 'local_uuid']);
        medicationUuids = {
          for (final m in meds)
            if (m['local_uuid'] != null) '${m['id']}': m['local_uuid'] as String,
        };
      }

      // A row can predate the migration's backfill only if it was inserted by an
      // older build mid-upgrade; give it an id rather than dropping it.
      final records = <Map<String, dynamic>>[];
      final uuids = <String>[];

      for (final row in rows) {
        var localUuid = row['local_uuid'] as String?;
        if (localUuid == null || localUuid.isEmpty) {
          localUuid = _uuid.v4();
          final written = await db.update(
            spec.table,
            {'local_uuid': localUuid},
            where: 'rowid = ?',
            whereArgs: [row['_rowid']],
          );

          // If the id could not be stored, sending the record would upload a
          // row that can never be acknowledged — and would be re-sent under a
          // new id on every pass. Skipping is the safe failure.
          if (written == 0) {
            debugPrint('🔄 Could not persist local_uuid for ${spec.table}; skipping row');
            continue;
          }
        }

        try {
          final source = spec.table == 'medication_logs'
              ? {...row, 'medication_local_uuid': medicationUuids['${row['medicationId']}']}
              : row;
          // `_rowid` needs no stripping: every mapper picks named keys, so the
          // query artefact never reaches the payload. sqflite rows are also
          // read-only, so removing it would throw.
          final body = spec.map(source)..removeWhere((_, v) => v == null);
          records.add({'local_uuid': localUuid, ...body});
          uuids.add(localUuid);
        } catch (e) {
          // A row we cannot even map is not going to succeed on retry. Park it
          // so one malformed record cannot block the whole queue forever.
          debugPrint('🔄 Unmappable ${spec.table} row parked: $e');
          await db.update(spec.table, {'pending_sync': 2},
              where: 'rowid = ?', whereArgs: [row['rowid']]);
        }
      }

      if (records.isEmpty) continue;

      try {
        final res = await ApiClient.I.dio.post(spec.endpoint, data: {
          'device_uuid': deviceUuid,
          'batch_uuid': _uuid.v4(),
          'records': records,
        });

        // 429 is the server asking us to slow down, not a broken record.
        // Retrying it on the normal schedule just earns another 429, so this
        // backs off hard and leaves the rows queued for a later pass.
        if (res.statusCode == 429) {
          debugPrint('🔄 ${spec.endpoint} rate-limited; backing off');
          _rateLimited = true;
          break;
        }

        if (res.statusCode != 200) {
          debugPrint('🔄 ${spec.endpoint} -> ${res.statusCode}');
          failed += records.length;
          break;
        }

        // Mark only what the server actually acknowledged. Anything missing from
        // `synced` stays pending and is retried, which is what makes a partial
        // failure safe.
        final synced = ((res.data['synced'] as List?) ?? []).cast<String>();
        if (synced.isNotEmpty) {
          final placeholders = List.filled(synced.length, '?').join(',');
          await db.rawUpdate(
            'UPDATE ${spec.table} SET pending_sync = 0, synced_at = ? '
            'WHERE local_uuid IN ($placeholders)',
            [DateTime.now().millisecondsSinceEpoch, ...synced],
          );
        }

        uploaded += synced.length;
        failed += records.length - synced.length;

        // A batch where nothing landed will not do better on the next loop.
        if (synced.isEmpty) break;
      } catch (e) {
        debugPrint('🔄 ${spec.endpoint} threw: $e');
        failed += records.length;
        break;
      }

      if (rows.length < _batchSize) break;
    }

    return SyncResult(uploaded: uploaded, failed: failed);
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    final delay = _backoff[_backoffStep.clamp(0, _backoff.length - 1)];
    _backoffStep++;
    debugPrint('🔄 Retrying sync in ${delay.inSeconds}s');
    _retryTimer = Timer(delay, () => unawaited(syncNow()));
  }

  // ---------- mapping helpers ----------

  static String? _iso(Object? millis) {
    if (millis == null) return null;
    final ms = millis is int ? millis : int.tryParse('$millis');
    if (ms == null || ms <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms).toUtc().toIso8601String();
  }

  /// `yyyymmdd` → `yyyy-mm-dd`.
  static String? _dateKeyToIso(String? key) {
    if (key == null || key.length != 8) return null;
    return '${key.substring(0, 4)}-${key.substring(4, 6)}-${key.substring(6)}';
  }

  /// The app stores these as display strings ("Present"/"Absent"); null must
  /// stay null, because "not assessed" is not "absent".
  static bool? _yesNo(Object? v) {
    if (v == null) return null;
    final s = '$v'.toLowerCase();
    if (s.contains('present') || s == 'yes' || s == 'true' || s == '1') return true;
    if (s.contains('absent') || s == 'no' || s == 'false' || s == '0') return false;
    return null;
  }

  static String? _risk(Object? infection, Object? ischaemia) {
    final i = _yesNo(infection) ?? false;
    final s = _yesNo(ischaemia) ?? false;
    if (i && s) return 'high';
    if (i) return 'infection';
    if (s) return 'ischaemia';
    return 'normal';
  }
}

/// Builds the tissue payload for a scan: every class with its probability and
/// threshold, plus the headline label.
///
/// Scans written before per-class findings existed still send their label, so
/// the server sees a consistent shape either way.
Map<String, dynamic>? _tissueJson(Map<String, Object?> r) {
  final label = r['tissueType'] as String?;
  final raw = r['tissueFindings'] as String?;

  List<dynamic>? findings;
  if (raw != null && raw.isNotEmpty) {
    try {
      findings = jsonDecode(raw) as List;
    } catch (_) {
      findings = null;
    }
  }

  if (label == null && findings == null) return null;

  return {
    if (label != null) 'label': label,
    if (findings != null) 'findings': findings,
  };
}
