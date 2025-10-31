
import 'package:diafootcare_new/routes/app_routes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import 'core/services/auth_services.dart';
import 'core/theme/dark_theme.dart';
import 'core/theme/light_theme.dart';
import 'features/auth/screens/confirm_code_screen.dart';
import 'features/auth/screens/otp_verify_screen.dart';
import 'features/auth/screens/reset_success_screen.dart';
import 'features/auth/screens/set_new_password_screen.dart';
import 'features/auth/viewmodel/forget_password_viewmodel.dart';
import 'features/home/screens/home_screen.dart';
import 'features/notes/viewmodel/notes_viewmodel.dart';
import 'features/profile/viewmodel/profile_viewmodel.dart';
import 'features/settings/viewmodel/settings_viewmodel.dart';
import 'features/shell/controllers/shell_controller.dart';
import 'features/reminders/viewmodel/reminders_viewmodel.dart';
import 'features/auth/screens/login_screen.dart';

class DiaFootApp extends StatelessWidget {
  const DiaFootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MultiProvider(
          providers: [
            Provider<AuthService>(create: (_) => AuthService()),     // needed by VMs
            ChangeNotifierProvider(create: (_) => ShellController()),
            ChangeNotifierProvider(create: (_) => RemindersViewModel()),
            ChangeNotifierProvider(create: (_) => NotesViewModel()),
            ChangeNotifierProvider(create: (_) => SettingsViewModel()),
            ChangeNotifierProvider(create: (_) => ProfileViewModel()),

          ],
          child: Builder(
            builder: (inner) {
              final themeMode = inner.watch<SettingsViewModel>().themeMode;
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                title: tr('app_name'),
                theme: lightTheme,
                darkTheme: darkTheme,
                themeMode: themeMode,
                localizationsDelegates: inner.localizationDelegates,
                supportedLocales: inner.supportedLocales,
                locale: inner.locale,

                initialRoute: AppRoutes.splash,
                routes: AppRoutes.routes,

                // ---------- UPDATED ----------
                onGenerateRoute: (settings) {
                  switch (settings.name) {
                    case AppRoutes.confirm: {
                      // Accepts either a String email OR a Map {'email','masked'}
                      String email = '';
                      String? masked;

                      final args = settings.arguments;
                      if (args is String) {
                        email = args;
                      } else if (args is Map) {
                        email  = (args['email']  ?? '') as String;
                        masked = args['masked'] as String?;
                      }

                      masked ??= ForgetPasswordViewModel.maskEmail(email);

                      return MaterialPageRoute(
                        builder: (_) => ConfirmCodeScreen(
                          maskedEmail: masked!,
                          email: email, // pass plain email forward
                        ),
                      );
                    }

                    case AppRoutes.otp: {
                      // Requires: {'email': 'plain', 'masked': 'm***'}
                      final args = settings.arguments as Map<String, dynamic>;
                      final email  = args['email'] as String;
                      final masked = (args['masked'] as String?) ??
                          ForgetPasswordViewModel.maskEmail(email);

                      return MaterialPageRoute(
                        builder: (_) => OtpVerifyScreen(
                          maskedEmail: masked,
                          email: email,
                        ),
                      );
                    }

                    case AppRoutes.resetSuccess: {
                      // Requires: {'email': 'plain', 'code': '123456'}
                      final args = settings.arguments as Map<String, dynamic>;
                      return MaterialPageRoute(
                        builder: (_) => ResetSuccessScreen(
                          email: args['email'] as String,
                          code:  args['code']  as String,
                        ),
                      );
                    }

                    case AppRoutes.setPassword: {
                      // Requires: {'email': 'plain', 'code': '123456'}
                      final args = settings.arguments as Map<String, dynamic>;
                      return MaterialPageRoute(
                        builder: (_) => const SetNewPasswordScreen(),
                        settings: RouteSettings(arguments: args), // read inside the screen
                      );
                    }
                  }
                  return null;
                },
              );
            },
          ),
        );
      },
    );
  }
}

class AuthStreamBuilder extends StatelessWidget {
  AuthStreamBuilder({super.key});
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          if (snapshot.hasData) {
            return const HomeScreen();
          } else {
            return const LoginScreen();
          }
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
