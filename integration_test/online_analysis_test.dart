import 'dart:convert';
import 'dart:io';

import 'package:diafootcare_new/core/network/api_client.dart';
import 'package:diafootcare_new/core/services/app_mode_service.dart';
import 'package:diafootcare_new/core/services/remote_analysis_service.dart';
import 'package:diafootcare_new/features/wound/analysis/services/ai_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Exercises online mode against a running server.
///
/// Requires Laravel reachable at the build's API_BASE_URL with the inference
/// sidecar behind it, and a valid token in DFC_TEST_TOKEN:
///
///   flutter test integration_test/online_analysis_test.dart -d <device> \
///     --dart-define=DFC_TEST_TOKEN=<sanctum token>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Base64 because a Sanctum token contains a '|', which the Windows command
  // processor treats as a pipe and splits the --dart-define on.
  const tokenB64 = String.fromEnvironment('DFC_TEST_TOKEN_B64');
  final token = tokenB64.isEmpty ? '' : utf8.decode(base64Decode(tokenB64));

  late File photo;

  setUp(() async {
    // The online path deliberately ignores asset paths, so the fixture has to
    // exist as a real file — the same shape as a photo from the camera.
    final bytes =
        (await rootBundle.load('assets/testdata/wound_sample.jpg')).buffer.asUint8List();
    final dir = await getTemporaryDirectory();
    photo = File('${dir.path}/wound_sample.jpg');
    await photo.writeAsBytes(bytes);

    SharedPreferences.setMockInitialValues({});
    await AppModeService.I.set(AppMode.online);
    if (token.isNotEmpty) await ApiClient.I.saveToken(token);
  });

  testWidgets('online mode analyses on the server', (tester) async {
    final r = await RemoteAnalysisService.I.analyse(
      photo.path,
      pixelsPerCm: 40,
      manualDepthCm: 1.5,
    );

    // ignore: avoid_print
    print('ONLINE_RESULT ${jsonEncode({
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

    expect(r.isFromModel, isTrue);
    expect(r.isCalibrated, isTrue);
    expect(r.depth, 1.5, reason: 'the probe depth must survive the round trip');
    expect(r.length, greaterThan(0));
    expect(r.riskBadge, isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('a failure surfaces a reason rather than invented numbers',
      (tester) async {
    // No models on this install and no usable server: the one situation where
    // returning a plausible-looking measurement would be actively harmful.
    await ApiClient.I.clearToken();

    Object? thrown;
    try {
      await AiService.instance.analyzeWound(photo.path, pixelsPerCm: 40);
    } catch (e) {
      thrown = e;
    }

    // ignore: avoid_print
    print('ONLINE_FAILURE ${thrown.runtimeType}: $thrown');

    expect(thrown, isA<RemoteAnalysisException>(),
        reason: 'an unauthenticated analysis must fail loudly, not quietly '
            'return a simulated wound');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
