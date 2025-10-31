import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../home/screens/home_screen.dart';
import '../../history/screens/wound_history_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../wound/capture/screens/capture_screen.dart';
import '../controllers/shell_controller.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    final pages = const [
      HomeScreen(),
      WoundHistoryScreen(),
      CaptureScreen(),
      ProfileScreen(),
    ];

    // Navbar background color
    final Color navBackgroundColor =
    t.brightness == Brightness.dark ? const Color(0xff1A2030) : t.scaffoldBackgroundColor;

    // Colors for icons/labels
    const Color activeColor = Color(0xff077FFF);
    final Color inactiveColor =
    t.brightness == Brightness.light ? Colors.grey : Colors.white;

    Widget _svgIcon(String asset, bool active) {
      return SvgPicture.asset(
        asset,
        width: 24,
        height: 24,
        colorFilter: ColorFilter.mode(
          active ? activeColor : inactiveColor,
          BlendMode.srcIn,
        ),
      );
    }

    Widget _icon(IconData icon, bool active) {
      return Icon(
        icon,
        size: 24,
        color: active ? activeColor : inactiveColor,
      );
    }

    return Consumer<ShellController>(
      builder: (context, shell, _) {
        return WillPopScope(
          onWillPop: () async {
            if (shell.index != 0) {
              shell.setIndex(0);
              return false;
            }
            return true;
          },
          child: Scaffold(
            body: SafeArea(
              top: true,
              bottom: false,
              child: IndexedStack(index: shell.index, children: pages),
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Container(
                color: navBackgroundColor,
                child: Padding(
                  padding: EdgeInsets.only(top: 6.h),
                  child: BottomNavigationBar(
                    currentIndex: shell.index,
                    onTap: shell.setIndex,
                    type: BottomNavigationBarType.fixed,
                    elevation: 0,
                    backgroundColor: navBackgroundColor,
                    selectedItemColor: activeColor,
                    unselectedItemColor: inactiveColor,
                    selectedLabelStyle: TextStyle(fontSize: 12.sp),
                    unselectedLabelStyle: TextStyle(fontSize: 12.sp),
                    items: [
                      BottomNavigationBarItem(
                        icon: _svgIcon("assets/svg/home.svg", false),
                        activeIcon: _svgIcon("assets/svg/home_filled.svg", true),
                        label: 'nav_home'.tr(),
                        tooltip: 'nav_home'.tr(),
                      ),
                      BottomNavigationBarItem(
                        icon: _icon(Icons.schedule_outlined, false),
                        activeIcon: _icon(Icons.schedule_rounded, true),
                        label: 'nav_history'.tr(),
                        tooltip: 'nav_history'.tr(),
                      ),
                      BottomNavigationBarItem(
                        icon: _svgIcon("assets/svg/scan.svg", false),
                        activeIcon: _svgIcon("assets/svg/scan_filled.svg", true),
                        label: 'nav_capture'.tr(),
                        tooltip: 'nav_capture'.tr(),
                      ),
                      BottomNavigationBarItem(
                        icon: _svgIcon("assets/svg/user.svg", false),
                        activeIcon: _svgIcon("assets/svg/user_filled.svg", true),
                        label: 'nav_profile'.tr(),
                        tooltip: 'nav_profile'.tr(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
