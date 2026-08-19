import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:diafootcare_new/features/wound/analysis/services/ring_detector.dart';

/// Does the app's own calibration produce the centimetres the clinic measured?
///
/// The unit test above checks the detector against the reference detector — that
/// they agree with each other. This asks the question that matters to a patient:
/// take a real clinic photograph, find the ring the way the app now does, and see
/// whether the scale it yields turns the wound into the size a clinician wrote
/// down with a ruler.
///
/// It exercises only the calibration half, deliberately. The segmentation half
/// runs a 12 MB TFLite model that the test harness has no business loading, and
/// it is measured separately on all 239 photographs by the Python pipeline. What
/// cannot be checked there — and can be checked here — is whether the **Dart**
/// path from photograph to pixels-per-cm is sound.
///
/// Skips when the clinical archive is absent, since it holds patient photographs
/// and does not live in the repo.
void main() {
  const archive = r'D:\DF\clinical_validation\annotate';
  final ringsFile = File('$archive\\rings.json');
  final manifestFile = File('$archive\\manifest.json');
  final available = ringsFile.existsSync() && manifestFile.existsSync();

  test('the app\'s scale reproduces the clinic\'s pixels-per-cm', () {
    if (!available) {
      markTestSkipped('clinical archive not on this machine');
      return;
    }

    final rings = jsonDecode(ringsFile.readAsStringSync()) as Map<String, dynamic>;
    final manifest =
        (jsonDecode(manifestFile.readAsStringSync()) as List).cast<Map<String, dynamic>>();

    const detector = RingDetector();
    final ppcErrors = <double>[];
    final rows = <String>[];

    // One photograph per wound, across both hospitals and both label sizes.
    final seen = <String>{};
    for (final m in manifest) {
      final wound = '${m['batch']}|${m['patient']}';
      if (!seen.add(wound)) continue;
      final name = m['file'] as String;
      final ref = rings[name] as Map<String, dynamic>?;
      if (ref == null) continue;
      final f = File('$archive\\images\\$name');
      if (!f.existsSync()) continue;

      final image = img.decodeImage(f.readAsBytesSync());
      if (image == null) continue;
      final got = detector.detect(image);
      if (got == null) {
        rows.add('$name: no ring');
        continue;
      }

      final refPpc = (ref['ppc'] as num).toDouble();
      final err = (got.pixelsPerCm - refPpc).abs() / refPpc;
      ppcErrors.add(err);
      rows.add('${name.padRight(18)} '
          '${got.pixelsPerCm.toStringAsFixed(1)} vs ${refPpc.toStringAsFixed(1)} px/cm '
          '(${(100 * err).toStringAsFixed(1)}%)  '
          'tilt ${got.tiltDeg.toStringAsFixed(0)}°  '
          '${got.isSmall ? "small" : "standard"}');
    }

    ppcErrors.sort();
    final worst = ppcErrors.isEmpty ? 1.0 : ppcErrors.last;
    final mean = ppcErrors.isEmpty
        ? 1.0
        : ppcErrors.reduce((a, b) => a + b) / ppcErrors.length;

    // ignore: avoid_print
    print('scale on ${ppcErrors.length} distinct wounds: '
        'mean ${(100 * mean).toStringAsFixed(1)}%, '
        'worst ${(100 * worst).toStringAsFixed(1)}%\n${rows.join('\n')}');

    expect(ppcErrors.length, greaterThanOrEqualTo(15),
        reason: 'the archive should cover enough wounds to mean something');
    // Repeatability of the ring itself in the clinic is ±1.8–5%, so a port that
    // adds more than a couple of percent on top is adding its own error.
    expect(mean, lessThan(0.02));
    expect(worst, lessThan(0.06));
  }, timeout: const Timeout(Duration(minutes: 10)));
}
