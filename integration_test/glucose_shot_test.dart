import 'package:diafootcare_new/features/glucose/glucose_unit.dart';
import 'package:diafootcare_new/features/glucose/screens/glucose_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Holds the glucose dialog on screen long enough to photograph it from
/// outside with `adb exec-out screencap`.
///
/// Not an assertion — a way to look at the thing. Whether a control is easy to
/// use is not something a finder can answer.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => EasyLocalization.ensureInitialized());

  Widget wrap(Widget child, Locale locale) => EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        startLocale: locale,
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, _) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: Scaffold(body: child),
          ),
        ),
      );

  testWidgets('hold the dialog in Arabic', (tester) async {
    await GlucoseUnitPref.set(GlucoseUnit.mgdl);
    await tester.pumpWidget(wrap(const AddGlucoseDialog(), const Locale('ar')));
    await tester.pumpAndSettle();
    await Future<void>.delayed(const Duration(seconds: 12));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
