import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:diafootcare_new/features/wound/analysis/services/ring_detector.dart';

/// Does the Dart ring detector agree with the one validated in the clinic?
///
/// The Python detector in `clinical_validation/scripts/ring_detect.py` was tuned
/// against 239 real photographs and its answers are recorded in `rings.json`.
/// This port has to reproduce them, because everything downstream — the scale,
/// the tilt gate, the label guard — is built on its numbers.
///
/// Scale is what matters, so the assertion is on the ring's measured diameter,
/// not on any intermediate. A 5% disagreement there is a 5% error in every wound
/// the app reports.
///
/// The archive lives outside the repo (it holds patient photographs), so these
/// tests **skip** rather than fail when it is absent — a machine without it can
/// still run the suite.
void main() {
  const archive = r'D:\DF\clinical_validation\annotate';
  final imagesDir = Directory('$archive\\images');
  final ringsFile = File('$archive\\rings.json');

  final available = imagesDir.existsSync() && ringsFile.existsSync();

  group('RingDetector vs the clinically validated detector', () {
    late Map<String, dynamic> expected;

    setUpAll(() {
      if (!available) return;
      expected = jsonDecode(ringsFile.readAsStringSync()) as Map<String, dynamic>;
    });

    test('finds the ring, and measures it to within 5%', () {
      if (!available) {
        markTestSkipped('clinical archive not on this machine');
        return;
      }
      const detector = RingDetector();
      final errors = <double>[];
      final tiltErrors = <double>[];
      var found = 0, missed = 0, wrongSize = 0;
      final misses = <String>[];

      // A sample, not all 90: decoding and scanning each photograph costs
      // real time, and 24 spread across both hospitals and every label type is
      // enough to catch a port that drifted.
      final files = expected.keys.toList()..sort();
      final sample = [
        for (var i = 0; i < files.length; i += (files.length / 24).ceil())
          files[i]
      ];

      for (final name in sample) {
        final f = File('${imagesDir.path}\\$name');
        if (!f.existsSync()) continue;
        final image = img.decodeImage(f.readAsBytesSync());
        if (image == null) continue;

        final ref = expected[name] as Map<String, dynamic>;
        final got = detector.detect(image);
        if (got == null) {
          missed++;
          misses.add(name);
          continue;
        }
        found++;

        final refMajor = (ref['major'] as num).toDouble();
        errors.add((got.majorPx - refMajor).abs() / refMajor);
        tiltErrors.add((got.tiltDeg - (ref['tilt'] as num).toDouble()).abs());
        if (got.isSmall != (ref['small'] as bool)) wrongSize++;
      }

      errors.sort();
      final median = errors.isEmpty ? 1.0 : errors[errors.length ~/ 2];
      final mean = errors.isEmpty
          ? 1.0
          : errors.reduce((a, b) => a + b) / errors.length;
      final within5 = errors.where((e) => e <= 0.05).length;

      // ignore: avoid_print
      print('ring detector: found $found, missed $missed of ${sample.length}\n'
          '  diameter error  median ${(100 * median).toStringAsFixed(1)}%  '
          'mean ${(100 * mean).toStringAsFixed(1)}%  '
          'within 5%: $within5/${errors.length}\n'
          '  tilt error      mean '
          '${(tiltErrors.isEmpty ? 0 : tiltErrors.reduce((a, b) => a + b) / tiltErrors.length).toStringAsFixed(1)}°\n'
          '  label size wrong: $wrongSize'
          '${misses.isEmpty ? '' : '\n  missed: ${misses.join(', ')}'}');

      expect(found, greaterThan(sample.length * 0.7),
          reason: 'the detector must find the ring in most clinic photographs');
      expect(median, lessThan(0.05),
          reason: 'a 5% scale error is a 5% error in every wound reported');
      // Reading the label size wrong scales every measurement by 4/3, so this
      // one is not allowed to drift at all.
      expect(wrongSize, 0, reason: 'label size decides the physical diameter');
    }, timeout: const Timeout(Duration(minutes: 10)));

    test('reports no ring rather than guessing when there is none', () {
      // A blank frame has nothing to lock onto. Returning null here is what lets
      // the app say "not calibrated" instead of inventing a scale — the failure
      // that reported a 1.4 cm wound as 0.9 cm.
      final blank = img.Image(width: 400, height: 300);
      img.fill(blank, color: img.ColorRgb8(180, 150, 140)); // plain skin tone
      expect(const RingDetector().detect(blank), isNull);
    });

    test('a solid disc of ink is refused — the mark is an annulus', () {
      // A blue surgical drape once became a 1102 px "ring", which would have
      // reported a whole foot as 2 cm wide.
      final im = img.Image(width: 400, height: 300);
      img.fill(im, color: img.ColorRgb8(180, 150, 140));
      img.fillCircle(im,
          x: 200, y: 150, radius: 60, color: img.ColorRgb8(0, 170, 200));
      expect(const RingDetector().detect(im), isNull);
    });

    test('a printed annulus is found, and its scale is the outer diameter', () {
      final im = img.Image(width: 400, height: 300);
      img.fill(im, color: img.ColorRgb8(180, 150, 140));
      img.fillCircle(im,
          x: 200, y: 150, radius: 60, color: img.ColorRgb8(0, 170, 200));
      img.fillCircle(im,
          x: 200, y: 150, radius: 38, color: img.ColorRgb8(255, 255, 255));

      final r = const RingDetector().detect(im);
      expect(r, isNotNull);
      // 120 px across for a 2 cm standard ring -> 60 px/cm.
      expect(r!.majorPx, closeTo(120, 12));
      expect(r.pixelsPerCm, closeTo(60, 6));
      expect(r.isSmall, isFalse);
      expect(r.tiltDeg, lessThan(12));
    });

    test('an ellipse reports the tilt that flattened it', () {
      // The ring's major axis is unforeshortened, so scale survives tilt while
      // the wound is compressed by cos θ. The gate needs this number to be right.
      final im = img.Image(width: 400, height: 300);
      img.fill(im, color: img.ColorRgb8(180, 150, 140));
      // 0.6 aspect -> acos(0.6) ≈ 53°. Drawn by hand because the image
      // package has no filled-ellipse primitive.
      void ellipse(int rx, int ry, img.Color c) {
        for (var y = -ry; y <= ry; y++) {
          for (var x = -rx; x <= rx; x++) {
            final u = x / rx, v = y / ry;
            if (u * u + v * v <= 1.0) im.setPixel(200 + x, 150 + y, c);
          }
        }
      }

      ellipse(60, 36, img.ColorRgb8(0, 170, 200));
      ellipse(38, 23, img.ColorRgb8(255, 255, 255));

      final r = const RingDetector().detect(im);
      expect(r, isNotNull);
      expect(r!.tiltDeg, closeTo(acos(0.6) * 180 / pi, 10));
      expect(r.majorPx, closeTo(120, 12),
          reason: 'the major axis is unforeshortened, so scale must hold');
    });
  });
}
