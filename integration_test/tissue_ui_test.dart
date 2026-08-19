import 'dart:io';

import 'package:diafootcare_new/core/services/model_download_service.dart';
import 'package:diafootcare_new/core/services/model_repository.dart';
import 'package:diafootcare_new/features/wound/analysis/screens/ai_result_screen.dart';
import 'package:diafootcare_new/features/wound/analysis/services/ai_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Renders the analysis result screen on a real device from a real wound
/// photograph, so the tissue breakdown is checked as a clinician would see it
/// rather than only as a list of numbers in a test.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await EasyLocalization.ensureInitialized();

    // The models are not in the APK — they are fetched from the server on first
    // use — and `flutter test integration_test` uninstalls the app when it
    // finishes, taking them with it. So every run starts on a device with no
    // models, and this test used to fail with ModelsUnavailableException before
    // reaching a single assertion. Fetching them here costs about seven minutes
    // on a cold device and nothing on a warm one.
    if (await ModelRepository.I.installedVersion() == null) {
      // ignore: avoid_print
      print('models absent — downloading the bundle first');
      final done = ModelDownloadService.I.stream.firstWhere((p) =>
          p.state == DownloadState.complete || p.state == DownloadState.failed);
      await ModelDownloadService.I.start();
      final end = await done;
      expect(end.state, DownloadState.complete,
          reason: 'the model bundle must download before the screen can render '
              'anything to assert on');
    }
  });

  /// Copies a bundled fixture out to a real file, because the analysis path
  /// treats asset paths as a special case.
  Future<String> fixture(String name) async {
    final bytes = (await rootBundle.load('assets/testdata/$name')).buffer.asUint8List();
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$name');
    await f.writeAsBytes(bytes);
    return f.path;
  }

  Widget wrap(Widget child) => EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, _) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: child,
          ),
        ),
      );

  testWidgets('the result screen shows every tissue found', (tester) async {
    final path = await fixture('200029.jpg');

    await AiService.instance.init();
    final result = await AiService.instance.analyzeWound(path, pixelsPerCm: 40);

    // ignore: avoid_print
    print('UI_RESULT headline=${result.primaryTissueType} '
        'summary=${result.tissueSummary} findings=${result.tissueFindings.length}');

    await tester.pumpWidget(wrap(AiResultScreen(result: result, imagePath: path)));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // This wound produces the longest label the screen can be asked to show —
    // "Necrosis, Slough, Granulation, Callus" — which overflowed the detail
    // card by 10 pixels when the value was still expected to be one word.
    expect(tester.takeException(), isNull,
        reason: 'the result screen must lay out without overflowing');

    // The tissue card sits below the fold — further down since the overlay
    // card ("What the app measured") joined the screen — and a ListView does
    // not build what is off screen. Without this the finders below search a
    // widget tree that stops at the measurements and pass or fail for reasons
    // that have nothing to do with tissue.
    await tester.scrollUntilVisible(find.byType(TissueBreakdown), 400);
    await tester.pumpAndSettle();

    // The summary, not a single label: this wound has four tissues present.
    expect(find.textContaining('Necrosis'), findsWidgets);
    expect(result.tissueFindings.where((f) => f.isPresent).length, greaterThan(1),
        reason: 'this fixture is the multi-tissue case worth rendering');

    // Every class appears in the breakdown, including the ones that did not
    // clear their threshold — an absence stated is better than one implied.
    for (final f in result.tissueFindings) {
      expect(find.textContaining(f.displayName), findsWidgets,
          reason: '${f.displayName} is missing from the breakdown');
    }

    // And no confidence figure is shown for any of them. This assertion was
    // once its exact opposite: the card showed a bar and a percentage per
    // class, on the reasoning that "Callus" should not read as a certainty.
    // In the clinic it did the opposite — "Necrosis 36%" against a 60%
    // threshold was read as *some necrosis*, when it means the model did not
    // find necrosis at all. Under and over threshold look alike as numbers.
    for (final f in result.tissueFindings) {
      expect(find.text('${(f.probability * 100).round()}%'), findsNothing,
          reason: 'a confidence figure is back for ${f.displayName}');
    }

    // What replaced it: the verdict in words, on every row.
    expect(find.text('Found'), findsWidgets);
    expect(find.text('Not found'), findsWidgets);

    // Held so an adb screencap from outside catches the rendered screen.
    // binding.takeScreenshot needs convertFlutterSurfaceToImage first, which
    // changes how the surface is composited — not worth altering what is being
    // verified in order to photograph it.
    await Future<void>.delayed(const Duration(seconds: 14));
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('a single-tissue wound reads cleanly too', (tester) async {
    final path = await fixture('200003.jpg');

    await AiService.instance.init();
    final result = await AiService.instance.analyzeWound(path, pixelsPerCm: 40);

    // ignore: avoid_print
    print('UI_RESULT headline=${result.primaryTissueType} '
        'summary=${result.tissueSummary}');

    await tester.pumpWidget(wrap(AiResultScreen(result: result, imagePath: path)));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(result.primaryTissueType, 'Granulation',
        reason: 'a visibly granulating bed must not be headlined as callus');

    await tester.scrollUntilVisible(find.byType(TissueBreakdown), 400);
    await tester.pumpAndSettle();
    expect(find.textContaining('Granulation'), findsWidgets);
    expect(find.text('Found'), findsWidgets);

    await Future<void>.delayed(const Duration(seconds: 14));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
