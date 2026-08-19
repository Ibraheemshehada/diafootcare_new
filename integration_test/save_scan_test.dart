import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:image/image.dart' as img;

import 'package:diafootcare_new/data/repositories/wounds_repository.dart';
import 'package:diafootcare_new/features/wound/analysis/services/overlay_renderer.dart';
import 'package:diafootcare_new/features/wound/analysis/services/ring_detector.dart';
import 'package:diafootcare_new/features/wound/analysis/viewmodel/analysis_result.dart';

/// Saving a scan, on a real device, on a **freshly created** database.
///
/// This is here because that combination failed and nothing caught it. The
/// `CREATE TABLE` for wounds was never updated when columns arrived by
/// migration, so a brand-new install got a table without `infectionProbability`
/// or `image_synced`. Every save ended in "We couldn't save the result" and
/// every sync pass threw on `image_synced` — but only for new users. Anyone
/// upgrading, which is every developer's own phone, was fine.
///
/// `PRAGMA user_version` reported the current version in both cases, so nothing
/// short of writing a row could tell the two apart.
///
/// Run after `adb shell pm clear tech.diafootcare.app`, which is what makes the
/// database fresh — reinstalling over an existing one does not.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const dir = '/data/data/tech.diafootcare.app/files';

  testWidgets('a scan saves, with its overlay and calibration', (tester) async {
    final photo = File('$dir/teston.jpg');
    expect(photo.existsSync(), isTrue, reason: 'push teston.jpg first');

    // The real path: find the ring, render an overlay beside the photograph,
    // then write the row exactly as the app does.
    final image = img.bakeOrientation(img.decodeImage(photo.readAsBytesSync())!);
    final ring = const RingDetector().detect(image);
    expect(ring, isNotNull, reason: 'the label is in this photograph');

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
    expect(overlay, isNotNull);
    expect(File(overlay!).existsSync(), isTrue);

    final result = AnalysisResult(
      length: 3.95,
      width: 3.67,
      depth: 0,
      area: 9.1,
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
    );

    final id = await WoundsRepository()
        .saveWoundResult(imagePath: photo.path, result: result);

    // The failure this guards against returned -1 and showed a dialog.
    expect(id, greaterThan(0), reason: 'the insert must actually write a row');

    final saved = await WoundsRepository().loadAllWounds();
    expect(saved, isNotEmpty);

    // ignore: avoid_print
    print('DEVICE save: row $id, ${saved.length} scan(s) in the database, '
        'overlay ${(File(overlay).lengthSync() / 1024).round()} KB, '
        '${ring.pixelsPerCm.toStringAsFixed(1)} px/cm, '
        'tilt ${ring.tiltDeg.toStringAsFixed(0)}°');
  });
}
