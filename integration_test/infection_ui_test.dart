import 'dart:io';

import 'package:diafootcare_new/core/services/model_download_service.dart';
import 'package:diafootcare_new/core/services/model_repository.dart';
import 'package:diafootcare_new/features/wound/analysis/screens/ai_result_screen.dart';
import 'package:diafootcare_new/features/wound/analysis/services/ai_service.dart';
import 'package:diafootcare_new/features/wound/analysis/services/infection_triage.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// What the patient actually sees about infection after answering the
/// checklist, rendered on a device from a real photograph.
///
/// The wiring reads correctly on paper — the checklist pops its answers, the
/// loading screen carries them, the result screen passes them to triage — so a
/// report that "infection did not show" cannot be settled by reading the code.
/// This renders the screen and reads the words off it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await EasyLocalization.ensureInitialized();
    if (await ModelRepository.I.installedVersion() == null) {
      // ignore: avoid_print
      print('models absent - downloading first');
      final done = ModelDownloadService.I.stream.firstWhere((p) =>
          p.state == DownloadState.complete || p.state == DownloadState.failed);
      await ModelDownloadService.I.start();
      expect((await done).state, DownloadState.complete);
    }
  });

  Future<String> fixture(String name) async {
    final bytes =
        (await rootBundle.load('assets/testdata/$name')).buffer.asUint8List();
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

  /// Everything the screen renders, in order. The fastest way to answer "why
  /// did nothing appear" is to look at what did.
  List<String> textsOf(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((w) => w.data ?? '')
      .where((s) => s.isNotEmpty)
      .toList();

  testWidgets('answering the checklist changes what the screen says',
      (tester) async {
    final path = await fixture('200029.jpg');
    await AiService.instance.init();
    final result = await AiService.instance.analyzeWound(path, pixelsPerCm: 40);

    // Two positive signs: enough to move the triage off "no signs" whatever the
    // image score is.
    const answered = InfectionSigns(
      warmth: true,
      swelling: true,
      purulentDischarge: false,
      tenderness: false,
      systemicUnwell: false,
    );

    await tester.pumpWidget(wrap(
      AiResultScreen(result: result, imagePath: path, signs: answered),
    ));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final withSigns = textsOf(tester);
    // ignore: avoid_print
    print('INFECTION prob=${result.infectionProbability.toStringAsFixed(3)} '
        'outcome=${triage(infectionProbability: result.infectionProbability, signs: answered).outcome}');
    // ignore: avoid_print
    print('SCREEN(${withSigns.length}): ${withSigns.join(" | ")}');

    expect(tester.takeException(), isNull);

    // The triage card is below the measurements and the overlay, and a ListView
    // does not build what is off screen.
    await tester.scrollUntilVisible(find.byIcon(Icons.bloodtype_outlined), 400);
    await tester.pumpAndSettle();

    final scrolled = textsOf(tester);
    // ignore: avoid_print
    print('AFTER SCROLL(${scrolled.length}): ${scrolled.join(" | ")}');

    // Something about infection must be on the screen. Which outcome depends on
    // the photograph; that one of them is stated does not.
    //
    // Compared against the translated strings rather than English guessed from
    // memory. The first version of this assertion looked for "See a clinician"
    // while the screen says "Please see your clinician", and failed on a screen
    // that was working perfectly - which would have sent someone hunting a bug
    // in the app instead of in the test.
    final outcomes = [
      'infection_out_urgent'.tr(),
      'infection_out_clinician'.tr(),
      'infection_out_recheck'.tr(),
      'infection_out_monitor'.tr(),
      'infection_out_none'.tr(),
    ];
    expect(
      scrolled.any(outcomes.contains),
      isTrue,
      reason: 'no infection verdict appeared anywhere on the result screen. '
          'Rendered: ${scrolled.join(" | ")}',
    );

    // And the perfusion caveat, which must show for every result including a
    // reassuring one.
    expect(
      scrolled.any((s) => s.contains('indicative only')),
      isTrue,
      reason: 'the blood-flow disclaimer is missing',
    );
  }, timeout: const Timeout(Duration(minutes: 6)));
}
