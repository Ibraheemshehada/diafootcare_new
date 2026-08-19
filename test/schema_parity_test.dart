import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:diafootcare_new/data/local/database_helper.dart';

/// A fresh install and an upgraded install must end up with the same tables.
///
/// They did not. `CREATE TABLE wounds` was never updated when columns were added
/// by migration, so a **brand-new user** got a table without `infectionProbability`
/// or `image_synced` — and every attempt to save a scan failed with
/// "table wounds has no column named infectionProbability", while every sync pass
/// failed on `image_synced`. Upgrading users were fine, which is why it survived:
/// the developers' own phones had been through the migrations.
///
/// `PRAGMA user_version` said 22 in both cases, so the version number could not
/// reveal it either. Only comparing the two schemas can.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Set<String>> columnsOf(Database db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.map((r) => r['name'] as String).toSet();
  }

  test('a fresh database has every column a migrated one has', () async {
    // Separate FILES, not the shared in-memory path: two in-memory handles are
    // the same database, so opening the second closed the first.
    final tmp = await Directory.systemTemp.createTemp('dfc_schema');
    final freshPath = p.join(tmp.path, 'fresh.db');
    final oldPath = p.join(tmp.path, 'old.db');

    // The oldest shape still in the field: the original wounds table, nothing
    // that any later migration adds.
    final seed = await databaseFactory.openDatabase(
      oldPath,
      options: OpenDatabaseOptions(
        version: 15,
        onCreate: (db, _) async {
          await db.execute("""
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
          """);
        },
      ),
    );
    await seed.close();

    // Now walk it through the real migration path, and create a fresh one.
    final upgraded = await DatabaseHelper().initDB(oldPath);
    final upgradedCols = await columnsOf(upgraded, 'wounds');
    await upgraded.close();

    DatabaseHelper.resetForTest();
    final fresh = await DatabaseHelper().initDB(freshPath);
    final freshCols = await columnsOf(fresh, 'wounds');
    await fresh.close();

    // This is the whole point. A column that only one path has is a feature
    // that works for some users and not others, with nothing to say which.
    expect(freshCols.difference(upgradedCols), isEmpty,
        reason: 'a fresh install has columns an upgrade never adds');
    expect(upgradedCols.difference(freshCols), isEmpty,
        reason: 'an upgrade has columns a fresh install never creates - which '
            'is how saving a scan failed on brand-new phones only');

    await tmp.delete(recursive: true);
  });

  test('the columns a scan is written with all exist', () async {
    // The insert in WoundsRepository names these. A column missing here is not
    // a warning at build time and not a failed test — it is a dialog reading
    // "We couldn't save the result" on a patient's phone.
    final db = await DatabaseHelper().initDB(inMemoryDatabasePath);
    final cols = await columnsOf(db, 'wounds');
    for (final c in const [
      'date', 'imagePath', 'overlayPath', 'pixelsPerCm', 'tiltDeg',
      'length', 'width', 'area', 'depth', 'analysedOn', 'tissueType',
      'tissueFindings', 'pusLevel', 'inflammation', 'infection',
      'infectionProbability', 'ischaemia', 'healingProgress', 'createdAt',
    ]) {
      expect(cols, contains(c), reason: 'saveWoundResult writes $c');
    }
    await db.close();
  });

  test('the sync query columns exist', () async {
    final db = await DatabaseHelper().initDB(inMemoryDatabasePath);
    final cols = await columnsOf(db, 'wounds');
    for (final c in const [
      'local_uuid', 'pending_sync', 'image_synced', 'imagePath', 'overlayPath',
    ]) {
      expect(cols, contains(c), reason: 'the image sync pass selects $c');
    }
    await db.close();
  });
}
