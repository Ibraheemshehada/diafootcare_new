import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/services/auth_services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../routes/app_routes.dart';
import '../../settings/viewmodel/settings_viewmodel.dart';
import '../viewmodel/profile_viewmodel.dart';
import '../widgets/profile_tile.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/app_mode_service.dart';
import '../../onboarding/screens/mode_choice_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final profile = context.watch<ProfileViewModel>();
    final settings = context.watch<SettingsViewModel>();

    return Scaffold(
      appBar: AppBar(title: Text('profile'.tr())),
      body: ListView(
        children: [
          // Header card
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
            child: Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: t.cardColor,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: t.colorScheme.outlineVariant.withOpacity(.30),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28.r,
                    backgroundImage: profile.avatarImageProvider,
                    child: profile.hasPhoto ? null : const Icon(Icons.person),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.fullName, style: t.textTheme.titleMedium),
                        SizedBox(height: 4.h),
                        Text(
                          profile.email,
                          style: t.textTheme.bodySmall?.copyWith(
                            color: t.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        TextButton(
                          onPressed:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const EditProfileScreen(),
                                ),
                              ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.edit, size: 16),
                              SizedBox(width: 6.w),
                              Text('edit_profile'.tr()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Other Profile Tiles (Edit Info, Change Password, etc.)
          ProfileTile(
            leading: Icons.badge_rounded,
            title: 'edit_personal_info'.tr(),
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                ),
          ),
          ProfileTile(
            leading: Icons.lock_rounded,
            title: 'change_password'.tr(),
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen(),
                  ),
                ),
          ),

          // How the wound is analysed. The mode screen tells participants they
          // can change this from their profile, and until now that was not
          // true — there was no way back to it after first run.
          ProfileTile(
            leading: Icons.analytics_outlined,
            title: 'mode_title_short'.tr(),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _AnalysisModeChip(),
                SizedBox(width: 8.w),
                Icon(
                  Icons.chevron_right_rounded,
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ModeChoiceScreen(blocking: false),
                ),
              );
              // The chip reads the stored mode, so it has to rebuild after the
              // screen that may have changed it closes.
              if (context.mounted) (context as Element).markNeedsBuild();
            },
          ),

          // 🔤 Language tile
          ProfileTile(
            leading: Icons.language_rounded,
            title: 'app_language'.tr(),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LanguageChip(), // shows EN / AR
                SizedBox(width: 8.w),
                Icon(
                  Icons.chevron_right_rounded,
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            onTap: () => _openLanguageSheet(context),
          ),

          ProfileTile(
            leading: Icons.dark_mode_rounded,
            title: 'dark_mode'.tr(),
            trailing: Switch(
              value: settings.isDarkPreferred,
              onChanged: settings.setDarkMode,
            ),
          ),
          ProfileTile(
            leading: Icons.notifications_active_rounded,
            title: 'notifications'.tr(),
            trailing: Switch(
              value: settings.notificationsEnabled,
              onChanged: (v) async {
                try {
                  await settings.setNotifications(v);
                } catch (e) {
                  if (context.mounted) {
                    await showAppError(
                      context,
                      'dialog_notifications_failed'.tr(),
                      technicalDetail: e,
                    );
                  }
                }
              },
            ),
            onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
          ),
          ProfileTile(
            leading: Icons.description_rounded,
            title: 'terms'.tr(),
            onTap: () {},
          ),
          ProfileTile(
            leading: Icons.elderly_rounded,
            title: 'senior_tips'.tr(),
            onTap: () {
              AnalyticsService.I.logHelp('senior_tips'); // help/tutorial usage
              Navigator.pushNamed(context, AppRoutes.seniorTips);
            },
          ),
          ProfileTile(
            leading: Icons.insights_rounded,
            title: 'usage_title'.tr(),
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.usage);
            },
          ),
          ProfileTile(
            leading: Icons.ios_share_rounded,
            title: 'export_data'.tr(),
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.exportData);
            },
          ),

          // Log out
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: ConstrainedBox(
              // minHeight (not an exact height): keeps the >=48dp touch
              // target while letting the button grow when the user
              // enlarges the system font. An exact height clipped labels.
              constraints: BoxConstraints(minHeight: 48.h),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.of(context).danger,
                ),
                onPressed: () async {
                  // Clear "Remember Me" and guest session preferences (local,
                  // fast).
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('rememberMe', false);
                  await prefs.setBool('is_guest', false);
                  debugPrint(
                    '🔓 Remember Me & guest session cleared on logout',
                  );

                  // Revoke the session in the background. The server-side
                  // POST /auth/logout is best-effort (signOut swallows network
                  // errors) and must not make the Log out button hang on a slow
                  // or offline connection — signOut() still clears the local
                  // token. So fire it and leave for the login screen at once.
                  unawaited(AuthService().signOut());

                  if (!context.mounted) return;
                  Navigator.pushReplacementNamed(context, AppRoutes.login);
                },
                icon: const Icon(Icons.logout_rounded),
                label: Text('logout'.tr()),
              ),
            ),
          ),
          SizedBox(height: 12.h),
        ],
      ),
    );
  }

  Future<void> _openLanguageSheet(BuildContext context) async {
    final current = context.locale;
    final result = await showModalBottomSheet<Locale>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('english'.tr()),
                trailing: Radio<Locale>(
                  value: const Locale('en'),
                  groupValue: current,
                  onChanged: (v) => Navigator.pop(ctx, v),
                ),
                onTap: () => Navigator.pop(ctx, const Locale('en')),
              ),
              ListTile(
                title: Text('arabic'.tr()),
                trailing: Radio<Locale>(
                  value: const Locale('ar'),
                  groupValue: current,
                  onChanged: (v) => Navigator.pop(ctx, v),
                ),
                onTap: () => Navigator.pop(ctx, const Locale('ar')),
              ),
            ],
          ),
        );
      },
    );

    if (result != null && result != current) {
      await context.setLocale(
        result,
      ); // EasyLocalization updates locale + RTL/LTR
    }
  }
}

class _LanguageChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final code = context.locale.languageCode;
    final label = code == 'ar' ? 'AR' : 'EN';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: t.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        label,
        style: t.textTheme.labelMedium?.copyWith(
          color: t.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// Shows whether analysis runs on this phone or on the server.
class _AnalysisModeChip extends StatelessWidget {
  const _AnalysisModeChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<AppMode?>(
      future: AppModeService.I.current(),
      builder: (context, snap) {
        final mode = snap.data;
        // Blank rather than a guess while it loads: this is a setting, and
        // showing the wrong one briefly invites someone to "correct" it.
        if (mode == null) return const SizedBox.shrink();

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Text(
            'mode_${mode.name}_title'.tr(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }
}
