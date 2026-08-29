import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Optional **read-aloud** assistant for long-form text (education articles,
/// the SUS participant declaration, self-care tips).
///
/// This is a *complement* to, not a replacement for, the platform screen
/// readers. TalkBack (Android) and VoiceOver (iOS) remain the real
/// accessibility path — they are driven by the widget `Semantics` tree. This
/// service simply lets a user who has **not** enabled a screen reader (common
/// among elderly patients) tap a button and hear the text.
///
/// Speech is best-effort, but no longer *silently* so. If the device has no TTS
/// engine, or no voice data for the current language, [speak] returns false and
/// the caller says so. It used to return nothing and do nothing: the button
/// flickered and the patient concluded the feature was broken, with no way to
/// learn that Arabic voice data simply was not installed — which is a settings
/// download away, and unguessable.
class VoiceAssistantService {
  VoiceAssistantService._();
  static final VoiceAssistantService I = VoiceAssistantService._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  String? _language;

  /// The text currently being spoken, or null when idle. Lets a button render
  /// a play/stop state without extra plumbing.
  final ValueNotifier<String?> speaking = ValueNotifier<String?>(null);

  /// Returns false when the requested language has no voice data.
  Future<bool> _ensureReady(String languageCode) async {
    if (!_ready) {
      _tts.setCompletionHandler(() => speaking.value = null);
      _tts.setCancelHandler(() => speaking.value = null);
      _tts.setErrorHandler((msg) {
        debugPrint('⚠️ TTS error: $msg');
        speaking.value = null;
      });

      // iOS needs its audio session configured explicitly or speak() is
      // silent: the app must claim the shared AVAudioSession, and the
      // `playback` category makes speech audible even with the ring/silent
      // switch on — elderly patients routinely keep the phone silenced, and a
      // read-aloud they deliberately tapped should be heard regardless.
      // Android and web neither need nor implement these calls, so they are
      // guarded to iOS to avoid a MissingPluginException there.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [IosTextToSpeechAudioCategoryOptions.duckOthers],
        );
      }

      // Resolve speak() when the utterance *finishes* rather than when it
      // starts, so the completion handler fires and the play/stop state stays
      // in sync on iOS.
      await _tts.awaitSpeakCompletion(true);

      // A slightly slower rate is easier for elderly listeners.
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      _ready = true;
    }
    // 'ar' and 'en' map to the closest installed voice.
    final lang = languageCode == 'ar' ? 'ar-SA' : 'en-US';
    if (_language != lang) {
      final available = await _tts.isLanguageAvailable(lang);
      if (available == true) {
        await _tts.setLanguage(lang);
        _language = lang;
      } else {
        // Do not fall through and speak anyway. The previous behaviour left
        // whatever language was set before in place, so Arabic text was handed
        // to an English voice, which reads it as noise.
        debugPrint('⚠️ TTS language unavailable: $lang');
        return false;
      }
    }
    return true;
  }

  /// Speak [text]. If the same text is already playing, this stops it (toggle).
  ///
  /// Returns false when nothing will be heard, so the caller can say why rather
  /// than leaving the patient tapping a button that does nothing.
  Future<bool> speak(String text, {required String languageCode}) async {
    try {
      if (speaking.value == text) {
        await stop();
        return true;
      }
      if (!await _ensureReady(languageCode)) return false;
      await _tts.stop();
      speaking.value = text;
      final result = await _tts.speak(text);
      // speak() returns 0 when the engine refused, most often because no voice
      // data is installed for the language.
      if (result == 0) {
        speaking.value = null;
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('⚠️ TTS speak failed: $e');
      speaking.value = null;
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // ignore
    }
    speaking.value = null;
  }
}
