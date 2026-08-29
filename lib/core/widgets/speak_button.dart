import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/analytics_service.dart';
import '../services/voice_assistant_service.dart';

/// A 48dp "read aloud" button that speaks [text] using the device TTS engine.
///
/// Complements TalkBack/VoiceOver for users who have not enabled a screen
/// reader. Carries a tooltip (which is also its screen-reader label) and
/// toggles to a stop icon while speaking.
class SpeakButton extends StatelessWidget {
  /// Text to read aloud. Build it from the already-localized strings on screen.
  final String text;

  /// Optional analytics label, e.g. 'education_article'.
  final String? analyticsName;

  final Color? color;

  const SpeakButton({
    super.key,
    required this.text,
    this.analyticsName,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final languageCode = context.locale.languageCode;
    return ValueListenableBuilder<String?>(
      valueListenable: VoiceAssistantService.I.speaking,
      builder: (context, current, _) {
        final isSpeaking = current == text;
        final label =
            isSpeaking ? 'a11y_stop_reading'.tr() : 'a11y_read_aloud'.tr();
        return IconButton(
          tooltip: label, // also the screen-reader label
          iconSize: 24.sp,
          constraints: BoxConstraints(minWidth: 48.w, minHeight: 48.h),
          color: color ?? Theme.of(context).colorScheme.primary,
          icon: Icon(isSpeaking ? Icons.stop_circle_outlined
                                : Icons.volume_up_outlined),
          onPressed: () async {
            if (!isSpeaking && analyticsName != null) {
              AnalyticsService.I.logHelp('read_aloud:$analyticsName');
            }
            final spoke = await VoiceAssistantService.I
                .speak(text, languageCode: languageCode);
            // Silence is the one outcome the button cannot express on its own.
            // Without this the patient taps, hears nothing, and has no way to
            // discover that the phone simply has no voice for their language.
            if (!spoke && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('a11y_no_voice'.tr())),
              );
            }
          },
        );
      },
    );
  }
}
