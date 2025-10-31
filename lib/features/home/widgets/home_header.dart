import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class HomeHeader extends StatelessWidget {
  final String userFirstName;
  final VoidCallback onNotifications;
  const HomeHeader({super.key, required this.userFirstName, required this.onNotifications});

  String _greeting(BuildContext context, String name) {
    final h = TimeOfDay.now().hour;
    final part = h < 12
        ? 'morning'
        : (h < 17 ? 'afternoon' : (h < 21 ? 'evening' : 'night'));
    // e.g. "greeting.morning"
    return 'greeting.$part'.tr(namedArgs: {'name': name});
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22.r,
            backgroundImage: const AssetImage("assets/images/avatar_placeholder.png"),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(context, userFirstName),
                  style: t.textTheme.titleMedium,
                ),
                Text(
                  'keep_taking_care'.tr(),
                  style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onNotifications,
            icon: const Icon(Icons.notifications_none_rounded),
          )
        ],
      ),
    );
  }
}
