import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../routes/app_routes.dart';
import '../../settings/viewmodel/settings_viewmodel.dart';
import '../viewmodel/profile_viewmodel.dart';
import '../widgets/profile_tile.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth

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
                border: Border.all(color: t.colorScheme.outlineVariant.withOpacity(.30)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28.r,
                    backgroundImage: profile.avatarAsset != null ? AssetImage(profile.avatarAsset!) : null,
                    child: profile.avatarAsset == null ? const Icon(Icons.person) : null,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.fullName, style: t.textTheme.titleMedium),
                        SizedBox(height: 4.h),
                        Text(profile.email, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                        TextButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
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
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
          ),
          ProfileTile(
            leading: Icons.lock_rounded,
            title: 'change_password'.tr(),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
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
                Icon(Icons.chevron_right_rounded, color: t.colorScheme.onSurfaceVariant),
              ],
            ),
            onTap: () => _openLanguageSheet(context),
          ),

          ProfileTile(
            leading: Icons.dark_mode_rounded,
            title: 'dark_mode'.tr(),
            trailing: Switch(value: settings.isDarkPreferred, onChanged: settings.setDarkMode),
          ),
          ProfileTile(
            leading: Icons.notifications_active_rounded,
            title: 'notifications'.tr(),
            trailing: Switch(value: settings.notificationsEnabled, onChanged: settings.setNotifications),
          ),
          ProfileTile(leading: Icons.description_rounded, title: 'terms'.tr(), onTap: () {}),
          ProfileTile(leading: Icons.elderly_rounded, title: 'senior_tips'.tr(), onTap: () {
            Navigator.pushNamed(context, AppRoutes.seniorTips);
          }),
          ProfileTile(leading: Icons.ios_share_rounded, title: 'export_data'.tr(), onTap: () {
            Navigator.pushNamed(context, AppRoutes.exportData);
          }),

          // Log out
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: SizedBox(
              height: 48.h,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () async {
                  // Clear "Remember Me" preference
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('rememberMe', false);
                  debugPrint('🔓 Remember Me cleared on logout');
                  
                  // Firebase logout
                  await FirebaseAuth.instance.signOut();
                  
                  // Navigate to login screen
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
      await context.setLocale(result); // EasyLocalization updates locale + RTL/LTR
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
        style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.onSecondaryContainer),
      ),
    );
  }
}
