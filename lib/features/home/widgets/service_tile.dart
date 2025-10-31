import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../data/models/service_item.dart';

class ServiceTile extends StatelessWidget {
  final ServiceItem item;
  final VoidCallback onTap;
  const ServiceTile({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    final Color iconColor = item.isPrimary
        ? (t.brightness == Brightness.dark ? Colors.white : t.colorScheme.onPrimary)
        : t.colorScheme.primary;

    final Decoration baseDecoration = BoxDecoration(
      color: item.isPrimary ? null : t.cardColor,
      gradient: item.isPrimary
          ? LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
        t.colorScheme.primary.withOpacity(.95),
      t.colorScheme.primary
        ],
      )
          : null,
      borderRadius: BorderRadius.circular(24.r),
      boxShadow: const [BoxShadow(blurRadius: 16, color: Colors.black26, offset: Offset(0, 8))],
      border: item.isPrimary ? null : Border.all(color: t.colorScheme.outlineVariant.withOpacity(.12)),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24.r),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.r),
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final h = c.maxHeight;

            // Size the bg relative to the tile size
            final bgW = w * item.bgScale;
            final bgH = h * item.bgScale;

            // Offset in *tile* units (so it adapts to any grid size)
            final dx = w * item.bgOffsetX;
            final dy = h * item.bgOffsetY;

            return Stack(
              children: [
                // 1) Base
                Container(decoration: baseDecoration),

                // 2) Decorative SVG (optional)
                if (item.bgSvgAsset != null)
                  Positioned(
                    // Anchor to chosen alignment and then nudge by offsets
                    left: item.bgAlignment == Alignment.centerLeft
                        ? -dx
                        : (item.bgAlignment == Alignment.topLeft || item.bgAlignment == Alignment.bottomLeft
                        ? -dx
                        : null),
                    right: item.bgAlignment == Alignment.centerRight
                        ? -dx
                        : (item.bgAlignment == Alignment.topRight || item.bgAlignment == Alignment.bottomRight
                        ? -dx
                        : null),
                    top: (item.bgAlignment == Alignment.topLeft ||
                        item.bgAlignment == Alignment.topCenter ||
                        item.bgAlignment == Alignment.topRight)
                        ? -dy
                        : null,
                    bottom: (item.bgAlignment == Alignment.bottomLeft ||
                        item.bgAlignment == Alignment.bottomCenter ||
                        item.bgAlignment == Alignment.bottomRight)
                        ? -dy
                        : null,
                    child: IgnorePointer(
                      child: SizedBox(
                        width: bgW,
                        height: bgH,
                        child: SvgPicture.asset(
                          item.bgSvgAsset!,
                          fit: BoxFit.contain,
                          alignment: item.bgAlignment,
                          colorFilter: ColorFilter.mode(
                            (item.isPrimary ? Colors.white : t.colorScheme.onSurface)
                                .withOpacity(item.bgOpacity),
                            BlendMode.srcATop,
                          ),
                        ),
                      ),
                    ),
                  ),

                // 3) Foreground content
                Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SvgPicture.asset(
                        item.iconAsset,
                        width: 28.w,
                        height: 28.w,
                        color: iconColor,
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        item.title.tr(),
                        style: (item.isPrimary
                            ? t.textTheme.titleMedium?.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w700)
                            : t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        item.subtitle.tr(),
                        style: (item.isPrimary
                            ? t.textTheme.bodySmall?.copyWith(color: Colors.white.withOpacity(.9))
                            : t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
