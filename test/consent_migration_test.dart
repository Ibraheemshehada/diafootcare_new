import 'dart:io';

import 'package:diafootcare_new/data/local/database_helper.dart';
import 'package:diafootcare_new/data/models/consent_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Exercises the **real** v12 → v13 migration in `DatabaseHelper`.
///
/// Every existing DiaFootCare install has to pass through this migration, and a
/// failure would either lose SUS responses or trap the participant behind a
/// consent gate the app cannot record an answer to. Both are worse than a bug
/// in a normal feature, so the migration is tested rather than eyeballed.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('diafoot_migration_test');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  /// Builds a database shaped like a real v12 install: the pre-v13
  /// `sus_responses` table (no `consent_version`), no `consents` table.
  Future<String> createV12Database({int susRows = 0}) async {
    final path = '${tmp.path}/diafoot.db';
    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 12),
    );

    await db.execute('''
      CREATE TABLE sus_responses (
        id       TEXT PRIMARY KEY,
        dateTime INTEGER NOT NULL,
        q1  INTEGER NOT NULL, q2  INTEGER NOT NULL,
        q3  INTEGER NOT NULL, q4  INTEGER NOT NULL,
        q5  INTEGER NOT NULL, q6  INTEGER NOT NULL,
        q7  INTEGER NOT NULL, q8  INTEGER NOT NULL,
        q9  INTEGER NOT NULL, q10 INTEGER NOT NULL
      )
    ''');

    for (var i = 0; i < susRows; i++) {
      await db.insert('sus_responses', {
        'id': 'old-$i',
        'dateTime': DateTime(2026, 7, i + 1).millisecondsSinceEpoch,
        for (var q = 1; q <= 10; q++) 'q$q': 3,
      });
    }

    await db.close();
    return path;
  }

  Future<bool> hasColumn(Database db, String table, String column) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    return info.any((row) => row['name'] == column);
  }

  test('v12 -> v13 adds the consents table and the consent_version column',
      () async {
    final path = await createV12Database(susRows: 3);

    final db = await DatabaseHelper().initDB(path);

    expect(await db.getVersion(), 13);
    expect(await hasColumn(db, 'sus_responses', 'consent_version'), isTrue);

    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='consents'");
    expect(tables, isNotEmpty, reason: 'consents table should exist after v13');

    await db.close();
  });

  test('migration preserves existing SUS responses', () async {
    final path = await createV12Database(susRows: 3);

    final db = await DatabaseHelper().initDB(path);
    final rows = await db.query('sus_responses');

    expect(rows.length, 3, reason: 'no response may be lost in the migration');
    // Answers must survive untouched — this is study data.
    expect(rows.every((r) => r['q1'] == 3 && r['q10'] == 3), isTrue);

    await db.close();
  });

  test('pre-existing responses are left unstamped, marking them as v1-era',
      () async {
    final path = await createV12Database(susRows: 3);

    final db = await DatabaseHelper().initDB(path);
    final rows = await db.query('sus_responses');

    // NULL is meaningful: it records that these answers were given under the
    // declaration promising on-device-only storage.
    expect(rows.every((r) => r['consent_version'] == null), isTrue);

    await db.close();
  });

  test('stamping fills only NULL rows and never rewrites an existing stamp',
      () async {
    final path = await createV12Database(susRows: 2);
    final db = await DatabaseHelper().initDB(path);

    // A response given after the v2 declaration was accepted.
    await db.insert('sus_responses', {
      'id': 'new-1',
      'dateTime': DateTime(2026, 8, 1).millisecondsSinceEpoch,
      for (var q = 1; q <= 10; q++) 'q$q': 4,
      'consent_version': kCurrentConsentVersion,
    });

    // Simulates a participant accepting a declaration that covers prior answers.
    final updated = await db.update(
      'sus_responses',
      {'consent_version': kCurrentConsentVersion},
      where: 'consent_version IS NULL',
    );

    expect(updated, 2, reason: 'only the two unstamped rows should change');

    final stamped = await db.query('sus_responses');
    expect(stamped.length, 3);
    expect(
      stamped.every((r) => r['consent_version'] == kCurrentConsentVersion),
      isTrue,
    );

    await db.close();
  });

  test('a fresh v13 install gets both the consents table and the column',
      () async {
    final path = '${tmp.path}/fresh.db';

    final db = await DatabaseHelper().initDB(path);

    expect(await db.getVersion(), 13);
    expect(await hasColumn(db, 'sus_responses', 'consent_version'), isTrue);

    // Recording consent must work on a fresh install, or the gate locks the
    // participant out of the app entirely.
    await db.insert('consents', {
      'id': 'c1',
      'version': kCurrentConsentVersion,
      'accepted_at': DateTime.now().millisecondsSinceEpoch,
      'locale': 'ar',
      'app_version': null,
      'covers_prior': 1,
    });

    final consents = await db.query('consents');
    expect(consents.length, 1);
    expect(consents.first['version'], kCurrentConsentVersion);
    expect(consents.first['covers_prior'], 1);

    await db.close();
  });
}
