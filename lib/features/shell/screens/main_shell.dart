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
              child: _LazyTabsBody(index: shell.index),
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

/// The four tab bodies, built lazily instead of all at once.
///
/// The previous `IndexedStack(children: [Home, History, Capture, Profile])`
/// built and kept every tab alive the instant the shell appeared — so logging
/// in eagerly ran `CaptureScreen.initState` (which warms the ~208 MB TFLite
/// models) and `CaptureViewModel.init()` (which powers up the camera) while the
/// user was still on Home. That burst is what made login feel heavy.
///
/// Now:
///  - Home / History / Profile are built the first time they are opened and
///    then kept alive (state and scroll position survive tab switches). At
///    login only Home (index 0) is built.
///  - Capture is present in the tree **only while it is the selected tab**. It
///    is therefore created on entry (camera + model warm-up happen then, not at
///    login) and disposed on leave (the camera is released instead of idling in
///    the background). Re-entering rebuilds it; `AiService.init()` is idempotent
///    so the models are not reloaded.
class _LazyTabsBody extends StatefulWidget {
  final int index;
  const _LazyTabsBody({required this.index});

  @override
  State<_LazyTabsBody> createState() => _LazyTabsBodyState();
}

class _LazyTabsBodyState extends State<_LazyTabsBody> {
  static const int _captureIndex = 2;

  // Cheap tabs that have been opened at least once, and so should stay built.
  final Set<int> _activated = <int>{};

  Widget _pageFor(int i) {
    switch (i) {
      case 0:
        return const HomeScreen();
      case 1:
        return const WoundHistoryScreen();
      case 3:
        return const ProfileScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.index != _captureIndex) _activated.add(widget.index);

    return IndexedStack(
      index: widget.index,
      // Fill the parent. Without this the stack uses StackFit.loose and sizes
      // itself to its largest child — and because the inactive tabs are now
      // zero-size placeholders (not full-screen Scaffolds as before), that
      // collapsed the whole shell to nothing and rendered a blank screen. Expand
      // forces the visible tab to fill the viewport regardless of the
      // placeholders.
      sizing: StackFit.expand,
      children: List<Widget>.generate(4, (i) {
        if (i == _captureIndex) {
          // Only mount Capture while it is active, so leaving the tab disposes
          // it and frees the camera.
          return widget.index == _captureIndex
              ? const CaptureScreen()
              : const SizedBox.shrink();
        }
        // Lazy: an empty placeholder until the tab is first opened, then the
        // real page, which IndexedStack keeps alive offstage afterwards.
        return _activated.contains(i) ? _pageFor(i) : const SizedBox.shrink();
      }),
    );
  }
}
