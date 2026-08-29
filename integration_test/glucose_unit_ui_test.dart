import 'package:diafootcare_new/features/glucose/glucose_unit.dart';
import 'package:diafootcare_new/features/glucose/screens/glucose_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Choosing the glucose unit while entering a reading.
///
/// The unit used to be a suffix inside the field and nothing else: to change it
/// you left the dialog, found a menu behind it, switched, and started again.
/// A patient who does not find that menu types what their meter shows into a
/// field that means something else — and 6.2 stored as mg/dL is a fatal hypo
/// that never happened, while 110 stored as mmol/L is not survivable.
///
/// So this checks the two things that make it safe: the choice is visible where
/// the number is typed, and switching converts what is already there.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await EasyLocalization.ensureInitialized();
  });

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
            home: Scaffold(body: child),
          ),
        ),
      );

  setUp(() async {
    await GlucoseUnitPref.set(GlucoseUnit.mgdl);
  });

  testWidgets('both units are on screen, with an example of each',
      (tester) async {
    await tester.pumpWidget(wrap(const AddGlucoseDialog()));
    await tester.pumpAndSettle();

    // Visible without opening a menu — the whole point.
    expect(find.text('mg/dL'), findsWidgets);
    expect(find.text('mmol/L'), findsWidgets);

    // "mmol/L" tells a patient nothing; a typical reading tells them which one
    // matches the number on their meter.
    expect(find.text('e.g. 110'), findsOneWidget);
    expect(find.text('e.g. 6.1'), findsOneWidget);
  });

  testWidgets('switching the unit converts what is already typed',
      (tester) async {
    await tester.pumpWidget(wrap(const AddGlucoseDialog()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '110');
    await tester.pumpAndSettle();

    await tester.tap(find.text('mmol/L'));
    await tester.pumpAndSettle();

    // 110 mg/dL is 6.1 mmol/L. Leaving "110" in place would have stored a
    // reading roughly eighteen times the one the patient meant.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, '6.1');
    expect(GlucoseUnitPref.unit.value, GlucoseUnit.mmoll);

    // And back, without drift.
    await tester.tap(find.text('mg/dL'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '110');
  });

  testWidgets('an empty field survives a unit switch', (tester) async {
    await tester.pumpWidget(wrap(const AddGlucoseDialog()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('mmol/L'));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty);
    expect(tester.takeException(), isNull);
  });
}
