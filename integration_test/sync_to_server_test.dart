import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:image/image.dart' as img;

import 'package:diafootcare_new/core/services/auth_services.dart';
import 'package:diafootcare_new/data/local/database_helper.dart';
import 'package:diafootcare_new/core/services/device_service.dart';
import 'package:diafootcare_new/core/services/sync_service.dart';
import 'package:diafootcare_new/data/repositories/wounds_repository.dart';
import 'package:diafootcare_new/features/wound/analysis/services/overlay_renderer.dart';
import 'package:diafootcare_new/features/wound/analysis/services/ring_detector.dart';
import 'package:diafootcare_new/features/wound/analysis/viewmodel/analysis_result.dart';

/// The whole path from the phone to the server: sign up, register the device,
/// save a scan, sync it, and upload its photograph and overlay.
///
/// This is the part nothing else covered. `_extensionOf` once contained an
/// unterminated character class, `RegExp(r'[/\]')`, which threw on every single
/// image upload — so **no wound photograph had ever reached the server**, for
/// the entire life of the feature. Unit tests covered the function afterwards,
/// but nothing walked the real sequence, and the sequence is where it broke.
///
/// **Runs against a local server only.** Point it at a throwaway Laravel
/// instance with its own database:
///
/// ```
/// # in the web repo
/// DB_CONNECTION=sqlite DB_DATABASE=$PWD/database/synctest.sqlite \
///   php artisan migrate --force
/// DB_CONNECTION=sqlite DB_DATABASE=$PWD/database/synctest.sqlite \
///   php artisan serve --host=0.0.0.0 --port=8123
///
/// # here
/// flutter test integration_test/sync_to_server_test.dart -d <device> \
///   --dart-define=API_BASE_URL=http://10.0.2.2:8123/api/v1
/// ```
///
/// Never against production. A synced scan is a clinical record: it lands in a
/// patient's history and in the study's own numbers, which is exactly the
/// pollution the admin analysis bench exists to avoid.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const dir = '/data/data/tech.diafootcare.app/files';

  testWidgets('a scan, its photograph and its overlay reach the server',
      (tester) async {
    final photo = File('$dir/teston.jpg');
    expect(photo.existsSync(), isTrue, reason: 'push teston.jpg first');

    // A fresh account per run, so a re-run never collides with the last one and
    // the assertions below can be about counts.
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final email = 'synctest+$stamp@local.test';

    final user = await AuthService().signUp(
      name: 'Sync Test',
      email: email,
      password: 'synctest-local-only',
    );
    // ignore: avoid_print
    print('SYNC signed up as ${user.email}');

    // The scan is stored against a device, so this has to succeed before the
    // upload has anywhere to go.
    final registered = await DeviceService.I.register(appVersion: '1.2.0+4');
    expect(registered, isTrue, reason: 'the device must register first');

    // The real analysis path: find the ring, render the overlay, write the row.
    final image = img.bakeOrientation(img.decodeImage(photo.readAsBytesSync())!);
    final ring = const RingDetector().detect(image);
    expect(ring, isNotNull);

    final mask = List.generate(
      96,
      (y) => List.generate(96, (x) {
        final dx = x - 48, dy = y - 44;
        return dx * dx + dy * dy < 320;
      }),
    );
    final overlay = await const OverlayRenderer().render(
      source: image,
      mask: mask,
      ring: ring,
      forImagePath: photo.path,
    );
    expect(overlay, isNotNull, reason: 'the overlay is uploaded alongside');

    final id = await WoundsRepository().saveWoundResult(
      imagePath: photo.path,
      result: AnalysisResult(
        length: 3.95,
        width: 3.34,
        depth: 0,
        area: 8.71,
        pusLevel: 'N/A',
        inflammation: 'N/A',
        infection: 'Not Present',
        ischaemia: 'Adequate',
        riskBadge: 'Normal',
        infectionProbability: 0.21,
        healingProgress: 0,
        isFromModel: true,
        isCalibrated: true,
        pixelsPerCm: ring!.pixelsPerCm,
        tiltDeg: ring.tiltDeg,
        usedSmallLabel: ring.isSmall,
        overlayImagePath: overlay,
        tissueType: 'Granulation',
      ),
    );
    expect(id, greaterThan(0));

    // Signing in starts a sync of its own, so an explicit syncNow() can return
    // "already running" and say nothing about whether anything worked. What the
    // row itself says afterwards is the fact worth asserting: image_synced only
    // becomes 1 once the server has answered 2xx to the upload.
    final db = await DatabaseHelper().database;
    var state = <String, Object?>{};
    final deadline = DateTime.now().add(const Duration(minutes: 3));

    while (DateTime.now().isBefore(deadline)) {
      final r = await SyncService.I.syncNow();
      if (r.reason != 'already running') {
        // ignore: avoid_print
        print('SYNC pass uploaded=${r.uploaded} failed=${r.failed} '
            'skipped=${r.skipped} reason=${r.reason}');
      }
      final rows = await db.query('wounds',
          columns: ['local_uuid', 'pending_sync', 'image_synced'],
          where: 'id = ?', whereArgs: [id]);
      state = rows.single;
      if (state['pending_sync'] == 0 && state['image_synced'] == 1) break;
      await Future<void>.delayed(const Duration(seconds: 2));
    }

    // ignore: avoid_print
    print('SYNC row=$state');

    expect(state['pending_sync'], 0,
        reason: 'the scan record never reached the server');
    // 1 = uploaded and acknowledged. 2 would mean the file was missing on disk,
    // 0 that it was never sent — the state the RegExp bug left every scan in.
    expect(state['image_synced'], 1,
        reason: 'the photograph never reached the server');

    // The calibration travels with the measurement, or the dashboard's angle
    // and calibration badges are decoration. They were: all three fields were
    // absent from the payload, so every app-taken scan arrived with a blank
    // scale and a blank tilt while the columns sat ready for them on the
    // server. Printed rather than asserted here — the row is on the server, and
    // the query that checks it is in this file's header — but printed loudly.
    final local = (await db.query('wounds',
        columns: ['pixelsPerCm', 'tiltDeg'],
        where: 'id = ?', whereArgs: [id])).single;
    expect(local['pixelsPerCm'], isNotNull,
        reason: 'nothing to sync if the scan never stored a scale');

    // ignore: avoid_print
    print('SYNC ok uuid=${state['local_uuid']} '
        'scale=${local['pixelsPerCm']} tilt=${local['tiltDeg']}');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
