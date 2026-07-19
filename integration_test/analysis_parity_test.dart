import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

import 'package:diafootcare_new/features/wound/analysis/services/ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Runs the real on-device pipeline over a fixed image and prints the result.
///
/// This exists to be compared against `inference/parity_test.py` in the web
/// repo, which runs the same image through the server pipeline. Online and
/// offline mode must describe a wound the same way — a patient who switches
/// mode, or two patients on different modes, must not get different numbers
/// because of where the arithmetic ran.
///
/// Run with:
///   flutter test integration_test/analysis_parity_test.dart -d <device>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const images = ['assets/testdata/200003.jpg', 'assets/testdata/200029.jpg'];

  testWidgets('decoded pixels, to locate any divergence at its source',
      (tester) async {
    // If the two platforms disagree on the analysis, the first question is
    // whether they even agree on the pixels. JPEG decoders differ between
    // implementations, and a difference here explains a difference downstream
    // that no amount of matching the arithmetic can remove.
    for (final image in images) {
      final bytes = (await rootBundle.load(image)).buffer.asUint8List();
      final decoded = img.bakeOrientation(img.decodeImage(bytes)!);

      var sum = 0;
      for (var y = 0; y < decoded.height; y++) {
        for (var x = 0; x < decoded.width; x++) {
          final p = decoded.getPixel(x, y);
          sum += p.r.toInt() + p.g.toInt() + p.b.toInt();
        }
      }

      // The CLIP resize in isolation, to tell a preprocessing difference apart
      // from a model difference when the two platforms disagree.
      final scale = 224 / (decoded.width < decoded.height ? decoded.width : decoded.height);
      final rz = img.copyResize(
        decoded,
        width: (decoded.width * scale).round(),
        height: (decoded.height * scale).round(),
        interpolation: img.Interpolation.cubic,
      );
      var rzSum = 0;
      for (var y = 0; y < rz.height; y++) {
        for (var x = 0; x < rz.width; x++) {
          final p = rz.getPixel(x, y);
          rzSum += p.r.toInt() + p.g.toInt() + p.b.toInt();
        }
      }
      // ignore: avoid_print
      print('PARITY_RESIZE $image ${jsonEncode({
            'w': rz.width, 'h': rz.height, 'channel_sum': rzSum,
          })}');

      // ignore: avoid_print
      print('PARITY_PIXELS $image ${jsonEncode({
            'width': decoded.width,
            'height': decoded.height,
            'channel_sum': sum,
          })}');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('on-device analysis of the parity image', (tester) async {
    await AiService.instance.init();

    for (final image in images)
      for (final ppc in <double?>[null, 40.0]) {
      final r = await AiService.instance.analyzeWound(image, pixelsPerCm: ppc);

      // Printed as one JSON line so the comparison script can pick it out of
      // the log without parsing prose.
      // ignore: avoid_print
      print('PARITY_DART $image ${jsonEncode({
            'calibration': ppc,
            'length': r.length,
            'width': r.width,
            'depth': r.depth,
            'tissue_type': r.tissueType,
            'infection': r.infection,
            'ischaemia': r.ischaemia,
            'risk_badge': r.riskBadge,
            'healing_progress': r.healingProgress,
            'is_calibrated': r.isCalibrated,
            'is_from_model': r.isFromModel,
          })}');

      // A simulated result would silently pass a parity comparison against
      // itself, so fail loudly if the models did not actually load.
      expect(r.isFromModel, isTrue,
          reason: 'models must be loaded; a simulated result proves nothing');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
