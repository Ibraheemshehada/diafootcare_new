import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../data/models/note.dart';


class NoteCard extends StatelessWidget {
  final Note note;
  final int index;
  const NoteCard({super.key, required this.note, required this.index});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final locale = context.locale.toLanguageTag();
    final dateLabel = DateFormat.yMMMMd(locale).format(note.date);

    final paletteLight = <Color>[
      const Color(0xFFFFE7E0), // peach
      const Color(0xFFE7EEFF), // blue
      const Color(0xFFE8F5EE), // green
      const Color(0xFFF9E7FF), // purple
      const Color(0xFFEDEFF2), // gray
    ];
    final paletteDark = <Color>[
      const Color(0xFF3B2E2A),
      const Color(0xFF2A3142),
      const Color(0xFF26342C),
      const Color(0xFF352A3C),
      const Color(0xFF2C2F35),
    ];

    final bg = t.brightness == Brightness.dark
        ? paletteDark[index % paletteDark.length]
        : paletteLight[index % paletteLight.length];

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateLabel,
            style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• '),
              Expanded(
                child: Text(
                  note.text,
                  style: t.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
