import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:diafootcare_new/core/services/auth_services.dart';
import 'package:diafootcare_new/features/shell/screens/main_shell.dart';
import 'package:diafootcare_new/features/shell/controllers/shell_controller.dart';
import 'package:diafootcare_new/features/reminders/viewmodel/reminders_viewmodel.dart';
import 'package:diafootcare_new/features/notes/viewmodel/notes_viewmodel.dart';
import 'package:diafootcare_new/features/glucose/viewmodel/glucose_viewmodel.dart';
import 'package:diafootcare_new/features/medication/viewmodel/medication_viewmodel.dart';
import 'package:diafootcare_new/features/selfcare/viewmodel/self_care_viewmodel.dart';
import 'package:diafootcare_new/features/appointments/viewmodel/appointments_viewmodel.dart';
import 'package:diafootcare_new/features/wellbeing/viewmodel/wellbeing_viewmodel.dart';
import 'package:diafootcare_new/features/settings/viewmodel/settings_viewmodel.dart';
import 'package:diafootcare_new/features/profile/viewmodel/profile_viewmodel.dart';

/// Regression test for the blank main shell.
///
/// The lazy tab body renders inactive tabs as zero-size placeholders. If the
/// IndexedStack uses the default StackFit.loose it then sizes itself to those
/// placeholders and collapses to nothing — a blank screen. This test pumps the
/// real MainShell and asserts its body actually fills the viewport.
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
          designSize: const Size(375, 812),
          builder: (context, _) => MultiProvider(
            providers: [
              Provider<AuthService>(create: (_) => AuthService()),
              ChangeNotifierProvider(create: (_) => ShellController()),
              ChangeNotifierProvider(create: (_) => RemindersViewModel()),
              ChangeNotifierProvider(create: (_) => NotesViewModel()),
              ChangeNotifierProvider(create: (_) => GlucoseViewModel()),
              ChangeNotifierProvider(create: (_) => MedicationViewModel()),
              ChangeNotifierProvider(create: (_) => SelfCareViewModel()),
              ChangeNotifierProvider(create: (_) => AppointmentsViewModel()),
              ChangeNotifierProvider(create: (_) => WellbeingViewModel()),
              ChangeNotifierProvider(create: (_) => SettingsViewModel()),
              ChangeNotifierProvider(create: (_) => ProfileViewModel()),
            ],
            child: MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: child,
            ),
          ),
        ),
      );

  testWidgets('MainShell body fills the viewport (does not collapse to blank)',
      (tester) async {
    await tester.pumpWidget(wrap(const MainShell()));
    await tester.pump(const Duration(milliseconds: 300));

    final stack = find.byType(IndexedStack);
    expect(stack, findsOneWidget);

    // With the bug this is ~0; with StackFit.expand it fills the shell body.
    final size = tester.getSize(stack);
    expect(size.height, greaterThan(300),
        reason: 'shell body collapsed — the blank-screen bug is back');
    expect(size.width, greaterThan(200));
  });
}
