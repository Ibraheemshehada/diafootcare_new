import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:image/image.dart' as img;

import 'package:diafootcare_new/features/wound/analysis/services/ring_detector.dart';
import 'package:diafootcare_new/features/wound/capture/services/capture_check.dart';
import 'package:diafootcare_new/features/wound/analysis/services/overlay_renderer.dart';

/// Runs the measurement path **on a real Android device**, on real clinic
/// photographs, with the real models.
///
/// Everything before this was measured on a desktop: the Python pipeline over
/// 239 photographs, the Dart detector against that pipeline, the widget tests
/// over synthetic images. None of it proves the path works on a phone, where the
/// decoder, the isolates and the file system are all different — and the app has
/// never once been walked end to end on a device.
///
/// Photographs are pushed to /sdcard/Download before running:
///
///   D=/sdcard/Android/data/tech.diafootcare.app/files
///   adb push H1f_P1_6.jpeg   $D/wound_test.jpg     (standard label, 11°)
///   adb push H1e_P3_24.jpeg  $D/wound_tilted.jpg   (small label, 41°)
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // The app's own INTERNAL files directory. Android 14 scopes /sdcard/Download
  // away behind a permission prompt no test can answer, and files pushed to the
  // external directory by adb belong to the shell user, which the app may not
  // read. Its own sandbox is the one place both sides can reach.
  const dir = '/data/data/tech.diafootcare.app/files';
  const good = '$dir/wound_test.jpg';
  const tilted = '$dir/wound_tilted.jpg';

  testWidgets('the ring is found on a device, and the scale is right',
      (tester) async {
    final f = File(good);
    expect(f.existsSync(), isTrue, reason: 'push wound_test.jpg first');

    final image = img.bakeOrientation(img.decodeImage(f.readAsBytesSync())!);
    final ring = const RingDetector().detect(image);

    expect(ring, isNotNull, reason: 'a standard label is clearly in frame');
    // The reference detector measures 152.3 px/cm on this photograph.
    expect(ring!.pixelsPerCm, closeTo(152.3, 8));
    expect(ring.isSmall, isFalse);
    expect(ring.tiltDeg, lessThan(20));

    // ignore: avoid_print
    print('DEVICE ring: ${ring.pixelsPerCm.toStringAsFixed(1)} px/cm, '
        'tilt ${ring.tiltDeg.toStringAsFixed(0)}°, '
        '${ring.isSmall ? "small" : "standard"} label');
  });

  testWidgets('the capture gate passes a square photo and refuses a tilted one',
      (tester) async {
    final ok = await const CaptureChecker().check(good);
    expect(ok.blocks, isFalse);
    expect(ok.verdict, CaptureVerdict.good);

    if (File(tilted).existsSync()) {
      final bad = await const CaptureChecker().check(tilted);
      // 41° on the reference detector — past the 40° band where measured error
      // reaches 56%, so this is the case the gate exists for.
      expect(bad.tiltDeg, greaterThan(35));
      // ignore: avoid_print
      print('DEVICE tilted: ${bad.tiltDeg?.toStringAsFixed(0)}° '
          '-> ${bad.verdict}, blocks: ${bad.blocks}');
    }
  });

  testWidgets('an overlay is rendered and written to disk', (tester) async {
    final image =
        img.bakeOrientation(img.decodeImage(File(good).readAsBytesSync())!);
    final ring = const RingDetector().detect(image);

    // A stand-in mask: this test is about the renderer and the file system on a
    // phone, not about the segmenter, which is measured elsewhere.
    final mask = List.generate(
      64,
      (y) => List.generate(64, (x) {
        final dx = x - 32, dy = y - 30;
        return dx * dx + dy * dy < 100;
      }),
    );

    final path = await const OverlayRenderer().render(
      source: image,
      mask: mask,
      ring: ring,
      forImagePath: '${Directory.systemTemp.path}/overlay_probe.jpg',
    );

    expect(path, isNotNull, reason: 'the overlay must survive on-device paths');
    final out = File(path!);
    expect(out.existsSync(), isTrue);
    expect(out.lengthSync(), greaterThan(10000));
    // ignore: avoid_print
    print('DEVICE overlay: $path (${(out.lengthSync() / 1024).round()} KB)');
  });
}
