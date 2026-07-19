import 'dart:convert';
import 'dart:io';

import 'package:diafootcare_new/data/local/database_helper.dart';
import 'package:diafootcare_new/features/wound/analysis/viewmodel/analysis_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

TissueFinding f(String type, double p, double threshold) => TissueFinding(
      type: type,
      probability: p,
      isPresent: p >= threshold,
      thresholdUsed: threshold,
    );

/// The five classes as the model reports them, with their tuned thresholds.
List<TissueFinding> findings({
  double epithelial = 0.0,
  double granulation = 0.0,
  double necrosis = 0.0,
  double callus = 0.0,
  double slough = 0.0,
}) =>
    [
      f('epithelial', epithelial, 0.09),
      f('granulation', granulation, 0.43),
      f('necrosis', necrosis, 0.60),
      f('callus', callus, 0.45),
      f('slough', slough, 0.63),
    ];

void main() {
  group('primary tissue type', () {
    test('names the most serious class present, not the highest scoring', () {
      // The real case that motivated this: on one photograph necrosis and
      // callus both cleared their thresholds 0.013 apart, and whichever scored
      // higher won — which differed between the phone and the server.
      final r = findings(necrosis: 0.9887, callus: 0.9787, slough: 0.9193);
      expect(r.primaryType, 'Necrosis');

      // Swap the ranking; the headline must not move.
      final swapped = findings(necrosis: 0.9749, callus: 0.9911, slough: 0.9049);
      expect(swapped.primaryType, 'Necrosis');
    });

    test('does not headline callus over a strongly granulating bed', () {
      // Callus scraping over its 0.45 threshold must not outrank granulation
      // at 0.96 — that would bury the finding that describes the wound.
      final r = findings(granulation: 0.9632, callus: 0.5299);
      expect(r.primaryType, 'Granulation');
    });

    test('ignores classes that did not clear their own threshold', () {
      // Necrosis at 0.49 is below its 0.60 threshold, so it is not present and
      // must not be reported however serious it would be.
      final r = findings(granulation: 0.96, necrosis: 0.49, callus: 0.60);
      expect(r.primaryType, 'Granulation');
    });

    test('falls back to the most probable class when nothing is present', () {
      final r = findings(granulation: 0.20, necrosis: 0.30, callus: 0.10);
      expect(r.primaryType, 'Necrosis');
    });

    test('is never blank', () {
      expect(<TissueFinding>[].primaryType, 'Unknown');
      expect(findings().primaryType, isNotEmpty);
    });
  });

  group('summary', () {
    test('lists every present class, most serious first', () {
      final r = findings(
          granulation: 0.53, necrosis: 0.99, callus: 0.98, slough: 0.87);
      expect(r.summary, 'Necrosis, Slough, Granulation, Callus');
    });

    test('omits classes that are absent', () {
      final r = findings(granulation: 0.96, callus: 0.53);
      expect(r.summary, 'Granulation, Callus');
    });
  });

  group('AnalysisResult', () {
    test('derives its headline from the findings', () {
      final r = AnalysisResult(
        length: 1,
        width: 1,
        depth: 0,
        tissueFindings: findings(granulation: 0.96, callus: 0.53),
        pusLevel: 'N/A',
        inflammation: 'N/A',
        healingProgress: 90,
      );
      expect(r.primaryTissueType, 'Granulation');
      expect(r.tissueType, 'Granulation', reason: 'legacy getter still works');
      expect(r.tissueSummary, 'Granulation, Callus');
    });

    test('falls back to a stored label when a record predates findings', () {
      // Scans written before per-class findings existed have only the label,
      // and must keep displaying it rather than reading "Unknown".
      final r = AnalysisResult(
        length: 1,
        width: 1,
        depth: 0,
        tissueType: 'Slough',
        pusLevel: 'N/A',
        inflammation: 'N/A',
        healingProgress: 90,
      );
      expect(r.primaryTissueType, 'Slough');
      expect(r.tissueSummary, 'Slough');
    });
  });

  test('survives a JSON round trip', () {
    final original = findings(granulation: 0.9632, callus: 0.5299);
    final encoded = jsonEncode(original.map((f) => f.toJson()).toList());
    final decoded = (jsonDecode(encoded) as List)
        .map((j) => TissueFinding.fromJson(Map<String, dynamic>.from(j as Map)))
        .toList();

    expect(decoded.length, original.length);
    for (var i = 0; i < original.length; i++) {
      expect(decoded[i].type, original[i].type);
      expect(decoded[i].probability, closeTo(original[i].probability, 1e-9));
      expect(decoded[i].isPresent, original[i].isPresent);
      expect(decoded[i].thresholdUsed, original[i].thresholdUsed);
    }
    expect(decoded.primaryType, original.primaryType);
  });

  group('schema v17 migration', () {
    late Directory tmp;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async => tmp = await Directory.systemTemp.createTemp('dfc_v17_'));
    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('adds tissueFindings without disturbing existing scans', () async {
      final path = '${tmp.path}/wounds.db';

      // A v16 database with a scan in it, as a patient upgrading would have.
      final old = await databaseFactory.openDatabase(path,
          options: OpenDatabaseOptions(version: 16, onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE wounds(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            imagePath TEXT NOT NULL,
            length REAL NOT NULL,
            width REAL NOT NULL,
            depth REAL,
            tissueType TEXT,
            pusLevel TEXT,
            inflammation TEXT
          )''');
        await db.insert('wounds', {
          'imagePath': '/tmp/a.jpg',
          'length': 2.0,
          'width': 1.0,
          'depth': 0.0,
          'tissueType': 'Slough',
          'pusLevel': 'N/A',
          'inflammation': 'N/A',
        });
      }));
      await old.close();

      final db = await DatabaseHelper().initDB(path);
      final rows = await db.query('wounds');

      expect(rows.length, 1, reason: 'the existing scan must survive');
      expect(rows.first['tissueType'], 'Slough',
          reason: 'its label must be untouched');
      expect(rows.first['tissueFindings'], isNull,
          reason: 'per-class probabilities were never stored and cannot be '
              'invented from a label');

      // And a new scan can carry findings.
      final encoded =
          jsonEncode(findings(granulation: 0.96).map((f) => f.toJson()).toList());
      await db.insert('wounds', {
        'imagePath': '/tmp/b.jpg',
        'length': 1.0,
        'width': 1.0,
        'tissueType': 'Granulation',
        'tissueFindings': encoded,
      });

      final fresh = await db.query('wounds', where: 'imagePath = ?', whereArgs: ['/tmp/b.jpg']);
      expect(fresh.first['tissueFindings'], encoded);

      await db.close();
    });
  });
}
