import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class DatabaseHelper {
  /// Current schema version.
  ///
  /// Exposed so tests assert against the same source of truth as the migration
  /// itself, instead of a literal that silently goes stale on the next bump.
  static const int schemaVersion = 17;

  static final DatabaseHelper _instance = DatabaseHelper._();
  static Database? _db;

  DatabaseHelper._();
  factory DatabaseHelper() => _instance;

  Future<Database> get database async {
    _db ??= await initDB();
    return _db!;
  }

  /// Opens (and migrates) the database.
  ///
  /// [overridePath] exists so tests can point the real `onCreate`/`onUpgrade`
  /// logic at a temporary file. Production callers pass nothing and get the
  /// usual `diafoot.db`. Without this the migrations could only ever be checked
  /// by hand on a device, which is a poor guarantee for a clinical schema that
  /// every existing install has to pass through.
  Future<Database> initDB([String? overridePath]) async {
    final path = overridePath ?? join(await getDatabasesPath(), 'diafoot.db');
    return openDatabase(
      path,
      version: schemaVersion, // 16: local_uuid assigned by trigger at insert
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE wounds (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            imagePath TEXT NOT NULL,
            length REAL NOT NULL,
            width REAL NOT NULL,
            depth REAL,
            tissueType TEXT,
            -- Per-class tissue findings as JSON: type, probability, whether it
            -- cleared its threshold, and the threshold used. tissueType above
            -- keeps the headline so history, exports and the dashboard are
            -- unaffected by records that predate this column.
            tissueFindings TEXT,
            pusLevel TEXT,
            inflammation TEXT,
            infection TEXT,
            ischaemia TEXT,
            healingProgress REAL,
            createdAt INTEGER NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_wounds_date ON wounds(date DESC)');

        // ⬇️ Create notes on fresh DB
        await db.execute('''
          CREATE TABLE notes (
            id   TEXT PRIMARY KEY,
            date INTEGER NOT NULL,
            text TEXT   NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_date ON notes(date DESC)');

        // ⬇️ Glucose readings on fresh DB
        await db.execute('''
          CREATE TABLE glucose_readings (
            id       TEXT PRIMARY KEY,
            value    REAL NOT NULL,
            dateTime INTEGER NOT NULL,
            tag      TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_glucose_dt ON glucose_readings(dateTime DESC)');

        // ⬇️ Medications + per-dose logs on fresh DB
        await _createMedicationTables(db);

        // ⬇️ Self-care daily check-in logs on fresh DB
        await _createSelfCareTable(db);

        // ⬇️ Appointments on fresh DB
        await _createAppointmentsTable(db);

        // ⬇️ Patient-reported outcomes (QoL + satisfaction) on fresh DB
        await _createWellbeingTables(db);

        // ⬇️ Engagement / usage analytics on fresh DB
        await _createAnalyticsTable(db);

        // ⬇️ System Usability Scale responses on fresh DB
        await _createSusTable(db);

        // ⬇️ Participant consent audit trail on fresh DB
        await _createConsentsTable(db);

        // ⬇️ Daily engagement rollups on fresh DB
        await _createEngagementDailyTable(db);

        // ⬇️ Sync queue columns on fresh DB
        await _addSyncColumns(db);

        // ⬇️ local_uuid assignment on fresh DB
        await _createUuidTriggers(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // ⬇️ Create notes on upgrade if missing
          await db.execute('''
            CREATE TABLE IF NOT EXISTS notes (
              id   TEXT PRIMARY KEY,
              date INTEGER NOT NULL,
              text TEXT   NOT NULL
            )
          ''');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_date ON notes(date DESC)');
        }
        if (oldVersion < 3) {
          // Update wounds table to include new fields. Each ALTER is guarded
          // separately so one already-existing column doesn't skip the rest.
          const alters = [
            'ALTER TABLE wounds ADD COLUMN imagePath TEXT',
            'ALTER TABLE wounds ADD COLUMN pusLevel TEXT',
            'ALTER TABLE wounds ADD COLUMN inflammation TEXT',
            'ALTER TABLE wounds ADD COLUMN healingProgress REAL',
            'ALTER TABLE wounds ADD COLUMN createdAt INTEGER',
          ];
          for (final sql in alters) {
            try {
              await db.execute(sql);
            } catch (e) {
              debugPrint('Note: wounds column may already exist: $e');
            }
          }
          await db.execute('CREATE INDEX IF NOT EXISTS idx_wounds_date ON wounds(date DESC)');
        }
        if (oldVersion < 4) {
          // Model 3: infection & ischaemia columns (guarded individually).
          const alters = [
            'ALTER TABLE wounds ADD COLUMN infection TEXT',
            'ALTER TABLE wounds ADD COLUMN ischaemia TEXT',
          ];
          for (final sql in alters) {
            try {
              await db.execute(sql);
            } catch (e) {
              debugPrint('Note: wounds column may already exist: $e');
            }
          }
        }
        if (oldVersion < 5) {
          // Glucose readings table.
          await db.execute('''
            CREATE TABLE IF NOT EXISTS glucose_readings (
              id       TEXT PRIMARY KEY,
              value    REAL NOT NULL,
              dateTime INTEGER NOT NULL,
              tag      TEXT NOT NULL
            )
          ''');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_glucose_dt ON glucose_readings(dateTime DESC)');
        }
        if (oldVersion < 6) {
          await _createMedicationTables(db);
        }
        if (oldVersion < 7) {
          await _createSelfCareTable(db);
        }
        if (oldVersion < 8) {
          await _createAppointmentsTable(db);
        }
        if (oldVersion < 9) {
          await _createWellbeingTables(db);
        }
        if (oldVersion < 10) {
          await _createAnalyticsTable(db);
        }
        if (oldVersion < 11) {
          await _createSusTable(db);
        }
        if (oldVersion < 12) {
          // `value` carries a numeric payload: screen dwell time in ms for
          // screen_close events, and is null for plain counter events.
          try {
            await db.execute(
                'ALTER TABLE analytics_events ADD COLUMN value INTEGER');
          } catch (e) {
            debugPrint('Note: analytics_events.value may already exist: $e');
          }
        }
        if (oldVersion < 13) {
          await _createConsentsTable(db);
          // Existing rows stay NULL on purpose: NULL means "collected under the
          // v1 declaration", which promised on-device-only storage. The column
          // preserves that fact even though the v2 text asks the participant to
          // extend consent to those responses — the study must still be able to
          // tell the two populations apart when analysing.
          try {
            await db.execute(
                'ALTER TABLE sus_responses ADD COLUMN consent_version INTEGER');
          } catch (e) {
            debugPrint('Note: sus_responses.consent_version may already exist: $e');
          }
        }
        if (oldVersion < 14) {
          await _addSyncColumns(db);
        }
        if (oldVersion < 15) {
          await _createEngagementDailyTable(db);
          await _addSyncColumns(db);
        }
        if (oldVersion < 16) {
          await _createUuidTriggers(db);
          // Anything inserted between v14 and this migration has no id yet.
          await _backfillMissingUuids(db);
        }
        if (oldVersion < 17) {
          // Existing scans keep their headline label and simply have no
          // findings; nothing is backfilled because the per-class
          // probabilities were never stored and cannot be recovered from a
          // label after the fact.
          //
          // Guarded like every other ALTER here. An upgrade step that assumes a
          // table exists will throw during onUpgrade, and a throw there fails
          // the database open — which is the app refusing to start, for a
          // column nobody has read yet.
          try {
            await db.execute('ALTER TABLE wounds ADD COLUMN tissueFindings TEXT');
          } catch (e) {
            debugPrint('Note: wounds.tissueFindings not added: $e');
          }
        }
      },
      onOpen: (db) async {
        // Extra safety: ensure table exists even if onCreate/onUpgrade didn't run
        await db.execute('''
          CREATE TABLE IF NOT EXISTS notes (
            id   TEXT PRIMARY KEY,
            date INTEGER NOT NULL,
            text TEXT   NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_date ON notes(date DESC)');

        // Extra safety: ensure glucose table exists
        await db.execute('''
          CREATE TABLE IF NOT EXISTS glucose_readings (
            id       TEXT PRIMARY KEY,
            value    REAL NOT NULL,
            dateTime INTEGER NOT NULL,
            tag      TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_glucose_dt ON glucose_readings(dateTime DESC)');

        // Extra safety: ensure medication tables exist
        await _createMedicationTables(db);

        // Extra safety: ensure self-care table exists
        await _createSelfCareTable(db);

        // Extra safety: ensure appointments table exists
        await _createAppointmentsTable(db);

        // Extra safety: ensure well-being (QoL + satisfaction) tables exist
        await _createWellbeingTables(db);

        // Extra safety: ensure analytics table exists
        await _createAnalyticsTable(db);

        // Extra safety: ensure SUS table exists
        await _createSusTable(db);

        // Extra safety: ensure the consent audit table exists. Consent must be
        // recordable even if a migration was interrupted — otherwise the app
        // would gate the user behind a declaration it cannot store.
        await _createConsentsTable(db);

        await _createEngagementDailyTable(db);

        // Extra safety: a table created by one of the onOpen guards above would
        // otherwise lack its sync columns and never upload.
        await _addSyncColumns(db);
        await _createUuidTriggers(db);
      },
    );
  }

  /// Tables whose rows are uploaded to the DiaFootCare server.
  ///
  /// `notes` is deliberately absent: free-text notes are the most sensitive and
  /// least structured thing a patient writes, and nothing in the study needs
  /// them. They stay on the device.
  static const List<String> syncableTables = [
    'wounds',
    'glucose_readings',
    'self_care_logs',
    'qol_entries',
    'satisfaction_entries',
    'appointments',
    'medications',
    'medication_logs',
    'sus_responses',
    'analytics_events',
    'engagement_daily',
    'consents',
  ];

  /// Adds the columns the sync queue needs to every syncable table.
  ///
  /// * `local_uuid` — a UUID v4 that identifies the row to the server. Generated
  ///   here rather than at upload time so a re-sent batch is recognisably the
  ///   same record and upserts instead of duplicating.
  /// * `pending_sync` — 1 until the server acknowledges the row.
  /// * `synced_at` — when that acknowledgement arrived.
  ///
  /// Existing rows are backfilled with generated UUIDs and left `pending_sync = 1`,
  /// so a participant's history uploads once rather than being stranded because
  /// it predates the queue.
  Future<void> _addSyncColumns(Database db) async {
    const uuid = Uuid();

    for (final table in syncableTables) {
      // Check first rather than attempting every ALTER and catching the failure.
      // This runs on every launch via the onOpen guard, and blindly retrying ~33
      // statements that are expected to fail is both wasteful and drowns the log
      // in exceptions that look like real errors.
      final Set<String> existing;
      try {
        final info = await db.rawQuery('PRAGMA table_info($table)');
        if (info.isEmpty) continue; // table not present on this install
        existing = info.map((c) => '${c['name']}').toSet();
      } catch (_) {
        continue;
      }

      final missing = {
        'local_uuid': 'ALTER TABLE $table ADD COLUMN local_uuid TEXT',
        'pending_sync':
            'ALTER TABLE $table ADD COLUMN pending_sync INTEGER NOT NULL DEFAULT 1',
        'synced_at': 'ALTER TABLE $table ADD COLUMN synced_at INTEGER',
      }..removeWhere((col, _) => existing.contains(col));

      for (final ddl in missing.values) {
        try {
          await db.execute(ddl);
        } catch (e) {
          debugPrint('Note: could not add sync column to $table: $e');
        }
      }

      // Backfill in one transaction per table.
      try {
        final rows = await db.query(table,
            columns: ['rowid'], where: 'local_uuid IS NULL');

        final batch = db.batch();
        for (final row in rows) {
          batch.update(table, {'local_uuid': uuid.v4()},
              where: 'rowid = ?', whereArgs: [row['rowid']]);
        }
        await batch.commit(noResult: true);

        await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_${table}_uuid ON $table(local_uuid)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_${table}_pending ON $table(pending_sync)');
      } catch (e) {
        debugPrint('Note: could not backfill $table: $e');
      }
    }
  }

  /// SQL that generates a RFC-4122 version-4 UUID.
  ///
  /// Written out because SQLite has no uuid function. The version nibble is
  /// pinned to `4` and the variant nibble to one of `8 9 a b`, so the result
  /// passes the server's `uuid` validation rule rather than merely looking like
  /// a UUID.
  static const _uuidExpression = """
    lower(hex(randomblob(4))) || '-' ||
    lower(hex(randomblob(2))) || '-4' ||
    substr(lower(hex(randomblob(2))), 2) || '-' ||
    substr('89ab', abs(random()) % 4 + 1, 1) ||
    substr(lower(hex(randomblob(2))), 2) || '-' ||
    lower(hex(randomblob(6)))
  """;

  /// Assigns `local_uuid` on insert, for every syncable table.
  ///
  /// A trigger rather than a line in each repository. The id must exist at
  /// capture time — that is what makes sync idempotent — and relying on nine
  /// repositories to remember is how it goes missing. It already did: rows
  /// inserted after the v14 migration had no id, sync generated a throwaway one
  /// per attempt, and 53 real events became 38,172 rows on the server.
  ///
  /// A repository may still supply its own id (the engagement rollups derive a
  /// deterministic one); the trigger only fills the gap when none was given.
  Future<void> _createUuidTriggers(Database db) async {
    for (final table in syncableTables) {
      try {
        final info = await db.rawQuery('PRAGMA table_info($table)');
        if (info.isEmpty) continue;

        await db.execute("""
          CREATE TRIGGER IF NOT EXISTS trg_${table}_local_uuid
          AFTER INSERT ON $table
          FOR EACH ROW WHEN NEW.local_uuid IS NULL
          BEGIN
            UPDATE $table SET local_uuid = ($_uuidExpression)
            WHERE rowid = NEW.rowid;
          END
        """);
      } catch (e) {
        debugPrint('Note: could not create uuid trigger for $table: $e');
      }
    }
  }

  /// Fills in ids for rows that predate the trigger.
  Future<void> _backfillMissingUuids(Database db) async {
    for (final table in syncableTables) {
      try {
        await db.execute(
          'UPDATE $table SET local_uuid = ($_uuidExpression) WHERE local_uuid IS NULL',
        );
      } catch (e) {
        debugPrint('Note: could not backfill uuids for $table: $e');
      }
    }
  }

  /// Daily rollups of high-volume engagement events.
  ///
  /// `local_uuid` is the primary key rather than an autoincrement id: it is
  /// derived deterministically from day+metric+target, so rebuilding a day
  /// replaces its row instead of appending another.
  Future<void> _createEngagementDailyTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS engagement_daily (
        local_uuid  TEXT PRIMARY KEY,
        day         TEXT NOT NULL,
        name        TEXT NOT NULL,
        target      TEXT,
        event_count INTEGER NOT NULL DEFAULT 0,
        total_value INTEGER
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_engagement_daily_day ON engagement_daily(day)');
  }

  /// Audit trail of participant consent decisions.
  ///
  /// Append-only by design: a new row per acceptance, never an update. A study
  /// has to be able to show *which* wording a participant agreed to and *when*,
  /// long after the text has been revised again. A single boolean in
  /// SharedPreferences cannot answer that question, and is trivially lost on
  /// reinstall.
  Future<void> _createConsentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS consents (
        id           TEXT PRIMARY KEY,
        version      INTEGER NOT NULL,
        accepted_at  INTEGER NOT NULL,
        locale       TEXT,
        app_version  TEXT,
        covers_prior INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_consents_version ON consents(version DESC)');
  }

  /// System Usability Scale: raw item responses are stored (q1..q10, each 1–5)
  /// rather than only the derived score, so the study can re-analyse per item.
  Future<void> _createSusTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sus_responses (
        id       TEXT PRIMARY KEY,
        dateTime INTEGER NOT NULL,
        consent_version INTEGER,
        q1  INTEGER NOT NULL,
        q2  INTEGER NOT NULL,
        q3  INTEGER NOT NULL,
        q4  INTEGER NOT NULL,
        q5  INTEGER NOT NULL,
        q6  INTEGER NOT NULL,
        q7  INTEGER NOT NULL,
        q8  INTEGER NOT NULL,
        q9  INTEGER NOT NULL,
        q10 INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sus_dt ON sus_responses(dateTime DESC)');
  }

  Future<void> _createAnalyticsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS analytics_events (
        id    INTEGER PRIMARY KEY AUTOINCREMENT,
        type  TEXT NOT NULL,
        name  TEXT,
        ts    INTEGER NOT NULL,
        value INTEGER
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_analytics_ts ON analytics_events(ts)');
  }

  Future<void> _createWellbeingTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS qol_entries (
        id        TEXT PRIMARY KEY,
        dateTime  INTEGER NOT NULL,
        pain      INTEGER NOT NULL,
        mobility  INTEGER NOT NULL,
        emotional INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_qol_dt ON qol_entries(dateTime DESC)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS satisfaction_entries (
        id          TEXT PRIMARY KEY,
        dateTime    INTEGER NOT NULL,
        ease        INTEGER NOT NULL,
        usefulness  INTEGER NOT NULL,
        willingness INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_satisfaction_dt ON satisfaction_entries(dateTime DESC)');
  }

  Future<void> _createAppointmentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS appointments (
        id           TEXT PRIMARY KEY,
        title        TEXT NOT NULL,
        dateTime     INTEGER NOT NULL,
        location     TEXT,
        notes        TEXT,
        reminderLead INTEGER NOT NULL,
        createdAt    INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_appointments_dt ON appointments(dateTime)');
  }

  Future<void> _createSelfCareTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS self_care_logs (
        logKey  TEXT PRIMARY KEY,
        itemKey TEXT NOT NULL,
        dateKey TEXT NOT NULL,
        doneAt  INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_selfcare_date ON self_care_logs(dateKey)');
  }

  Future<void> _createMedicationTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS medications (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        dosage      TEXT,
        timesPerDay INTEGER NOT NULL,
        createdAt   INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS medication_logs (
        doseKey      TEXT PRIMARY KEY,
        medicationId TEXT NOT NULL,
        dateKey      TEXT NOT NULL,
        doseIndex    INTEGER NOT NULL,
        takenAt      INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_medlogs_date ON medication_logs(dateKey)');
  }
}
