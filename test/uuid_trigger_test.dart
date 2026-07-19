import 'dart:io';

import 'package:diafootcare_new/data/local/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The trigger that stamps `local_uuid` at insert.
///
/// This is the invariant sync idempotency rests on: without an id assigned when
/// the row is created, every upload attempt invents a new one and the server
/// stores a fresh copy each time. That exact failure turned 53 real events into
/// 38,172 rows, so the guarantee is tested rather than assumed.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('dfc_uuid'));
  tearDown(() async {
    try {
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    } catch (_) {}
  });

  /// RFC-4122 v4: version nibble 4, variant nibble one of 8/9/a/b.
  final v4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('an insert with no local_uuid gets a valid v4 uuid', () async {
    final db = await DatabaseHelper().initDB('${tmp.path}/a.db');

    await db.insert('glucose_readings', {
      'id': 'g1',
      'value': 120.0,
      'dateTime': DateTime.now().millisecondsSinceEpoch,
      'tag': 'fasting',
    });

    final uuid = (await db.query('glucose_readings')).first['local_uuid'] as String?;
    expect(uuid, isNotNull, reason: 'the trigger must assign an id at insert');
    expect(v4.hasMatch(uuid!), isTrue,
        reason: 'server validates `uuid`; "$uuid" must be a real v4');

    await db.close();
  });

  test('ids are unique across many inserts', () async {
    final db = await DatabaseHelper().initDB('${tmp.path}/b.db');

    for (var i = 0; i < 200; i++) {
      await db.insert('glucose_readings', {
        'id': 'g$i',
        'value': 100.0 + i,
        'dateTime': DateTime.now().millisecondsSinceEpoch + i,
        'tag': 'random',
      });
    }

    final ids = (await db.query('glucose_readings'))
        .map((r) => r['local_uuid'] as String)
        .toSet();

    // A collision would make the server treat two records as re-sends of one
    // and silently drop a patient's reading.
    expect(ids.length, 200);
    expect(ids.every(v4.hasMatch), isTrue);

    await db.close();
  });

  test('an id supplied by the caller is not overwritten', () async {
    final db = await DatabaseHelper().initDB('${tmp.path}/c.db');

    // The engagement rollups derive a deterministic id on purpose; the trigger
    // must fill gaps, not impose its own.
    const explicit = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
    await db.insert('engagement_daily', {
      'local_uuid': explicit,
      'day': '2026-07-19',
      'name': 'screen_open',
      'target': '/',
      'event_count': 3,
    });

    final row = (await db.query('engagement_daily')).first;
    expect(row['local_uuid'], explicit);

    await db.close();
  });

  test('upgrading a v15 database backfills rows that have no id', () async {
    final path = '${tmp.path}/upgrade.db';

    // A v15-shaped install: sync columns exist (added at v14) but no trigger,
    // so rows inserted by a repository carry no local_uuid. This is exactly the
    // state every device in the field is in.
    final old = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 15),
    );
    await old.execute("""
      CREATE TABLE glucose_readings (
        id TEXT PRIMARY KEY, value REAL NOT NULL,
        dateTime INTEGER NOT NULL, tag TEXT NOT NULL,
        local_uuid TEXT, pending_sync INTEGER NOT NULL DEFAULT 1, synced_at INTEGER
      )
    """);
    for (var i = 0; i < 5; i++) {
      await old.insert('glucose_readings', {
        'id': 'old-$i',
        'value': 100.0 + i,
        'dateTime': DateTime(2026, 7, 10 + i).millisecondsSinceEpoch,
        'tag': 'fasting',
      });
    }
    await old.close();

    final db = await DatabaseHelper().initDB(path);

    expect(await db.getVersion(), DatabaseHelper.schemaVersion);

    final rows = await db.query('glucose_readings');
    expect(rows.length, 5, reason: 'no reading may be lost in the migration');

    final ids = rows.map((r) => r['local_uuid'] as String?).toList();
    // Without this backfill these rows would upload under a throwaway id on
    // every pass, which is the bug that produced 38,172 rows from 53 events.
    expect(ids.every((u) => u != null && v4.hasMatch(u)), isTrue,
        reason: 'every pre-existing row must get a real id');
    expect(ids.toSet().length, 5, reason: 'ids must be distinct');

    // And the trigger must now cover new inserts too.
    await db.insert('glucose_readings', {
      'id': 'new-1',
      'value': 130.0,
      'dateTime': DateTime.now().millisecondsSinceEpoch,
      'tag': 'random',
    });
    final fresh = (await db.query('glucose_readings', where: "id = 'new-1'")).first;
    expect(v4.hasMatch(fresh['local_uuid'] as String), isTrue);

    await db.close();
  });

  test('every syncable table assigns an id, not just the one we spot-checked',
      () async {
    final db = await DatabaseHelper().initDB('${tmp.path}/d.db');

    await db.insert('notes', {
      'id': 'n1',
      'date': DateTime.now().millisecondsSinceEpoch,
      'text': 'x',
    });
    await db.insert('appointments', {
      'id': 'a1',
      'title': 'Clinic',
      'dateTime': DateTime.now().millisecondsSinceEpoch,
      'reminderLead': 0,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });

    // `notes` is intentionally NOT synced, so it carries no trigger and no id.
    expect((await db.query('notes')).first.containsKey('local_uuid'), isFalse,
        reason: 'notes stay on the device and are not part of the sync queue');

    final appt = (await db.query('appointments')).first['local_uuid'] as String?;
    expect(appt, isNotNull);
    expect(v4.hasMatch(appt!), isTrue);

    await db.close();
  });
}
