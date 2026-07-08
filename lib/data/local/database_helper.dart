import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._();
  static Database? _db;

  DatabaseHelper._();
  factory DatabaseHelper() => _instance;

  Future<Database> get database async {
    _db ??= await initDB();
    return _db!;
  }

  Future<Database> initDB() async {
    final path = join(await getDatabasesPath(), 'diafoot.db');
    return openDatabase(
      path,
      version: 11, // ⬅️ bumped to 11 to add sus_responses (System Usability Scale)
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
      },
    );
  }

  /// System Usability Scale: raw item responses are stored (q1..q10, each 1–5)
  /// rather than only the derived score, so the study can re-analyse per item.
  Future<void> _createSusTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sus_responses (
        id       TEXT PRIMARY KEY,
        dateTime INTEGER NOT NULL,
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
        id   INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        name TEXT,
        ts   INTEGER NOT NULL
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
