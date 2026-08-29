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
    if (_language == languageCode) return true;
    if (await _selectVoice(languageCode)) {
      _language = languageCode;
      return true;
    }
    // Do not fall through and speak anyway. Leaving whatever language was set
    // before in place hands Arabic text to an English voice, which reads it as
    // noise.
    return false;
  }

  /// The voice actually in use, for diagnostics. Reported by the probe test.
  String? selectedVoice;

  /// Picks a voice rather than accepting whatever the engine defaults to.
  ///
  /// This used to ask for `ar-SA`, which is not a tag any Android engine
  /// lists: Google ships Arabic as `ar` with voices named `ar-xa-x-ard-local`
  /// and similar. `isLanguageAvailable('ar-SA')` still answered true, because
  /// Android matches loosely, and the engine then chose for itself — which is
  /// how a patient ends up with a voice nobody picked and nobody can explain.
  ///
  /// Ranked by, in order: how well the locale matches, then the quality the
  /// engine itself reports, then an installed voice over one that streams.
  /// The last is deliberate for this app: it is used offline in clinics, and a
  /// better voice that goes silent without a connection is a worse voice.
  Future<bool> _selectVoice(String languageCode) async {
    final wanted = languageCode == 'ar'
        ? const ['ar']
        : const ['en-us', 'en-gb', 'en'];
    try {
      final raw = await _tts.getVoices;
      final voices = (raw as List?)
              ?.map((v) => Map<String, dynamic>.from(v as Map))
              .where((v) => _localeRank('${v['locale']}', wanted) >= 0)
              .toList() ??
          [];

      if (voices.isNotEmpty) {
        voices.sort((a, b) {
          // A name chosen by ear wins outright. Everything below it is a guess
          // from metadata; this is the one thing in the ranking that comes from
          // somebody having actually listened.
          final byPreferred = _preferredRank('${a['name']}')
              .compareTo(_preferredRank('${b['name']}'));
          if (byPreferred != 0) return byPreferred;
          final byLocale = _localeRank('${a['locale']}', wanted)
              .compareTo(_localeRank('${b['locale']}', wanted));
          if (byLocale != 0) return byLocale;
          final byQuality = _qualityRank('${b['quality']}')
              .compareTo(_qualityRank('${a['quality']}'));
          if (byQuality != 0) return byQuality;
          // '1' means the voice streams from Google's servers.
          return '${a['network_required']}'.compareTo('${b['network_required']}');
        });

        final best = voices.first;
        await _tts.setVoice({
          'name': '${best['name']}',
          'locale': '${best['locale']}',
          // iOS matches on this first when it is present; Android ignores it.
          if (best['identifier'] != null) 'identifier': '${best['identifier']}',
        });
        selectedVoice = '${best['name']} (${best['locale']}, '
            'quality ${best['quality']})';
        debugPrint('🔊 TTS voice: $selectedVoice');
        return true;
      }
    } catch (e) {
      // getVoices is not implemented everywhere; fall through to the language.
      debugPrint('TTS voice list unavailable: $e');
    }

    // No voice list, or nothing matched: ask for the bare language tag, which
    // every engine understands.
    for (final tag in wanted) {
      if (await _tts.isLanguageAvailable(tag) == true) {
        await _tts.setLanguage(tag);
        selectedVoice = 'language $tag';
        return true;
      }
    }
    debugPrint('⚠️ TTS has no voice for $languageCode');
    selectedVoice = null;
    return false;
  }

  /// Voices picked by listening, best first.
  ///
  /// Everything else in the ranking reads metadata and hopes. On the test
  /// device every Arabic voice reports `quality: high`, so quality separates
  /// nothing and the winner among equals is whichever the engine happened to
  /// list first — which is no better than the default this replaced.
  ///
  /// Add a name here after auditioning it with
  /// integration_test/voice_audition_test.dart. A name that is not installed
  /// on a given device is simply skipped, so this list is safe to carry
  /// everywhere.
  static const List<String> _preferred = [
    // Nothing pinned yet. `ar-xa-x-arz-local` and `en-us-x-tpd-local` are what
    // the metadata ranking currently chooses, not what anyone chose.
  ];

  /// Lower is better; voices not in the list sort after every one that is.
  static int _preferredRank(String name) {
    final i = _preferred.indexOf(name);
    return i < 0 ? _preferred.length : i;
  }

  /// Lower is better; -1 means it does not match at all.
  static int _localeRank(String locale, List<String> wanted) {
    final l = locale.toLowerCase().replaceAll('_', '-');
    for (var i = 0; i < wanted.length; i++) {
      if (l == wanted[i]) return i;
    }
    for (var i = 0; i < wanted.length; i++) {
      if (l.startsWith('${wanted[i].split('-').first}-') ||
          l == wanted[i].split('-').first) {
        return wanted.length + i;
      }
    }
    return -1;
  }

  /// Android reports "very high".."very low"; Apple "premium"/"enhanced"/
  /// "default". Higher is better; an unknown word sits in the middle rather
  /// than at the bottom, so an unfamiliar engine is not penalised for wording.
  static int _qualityRank(String q) => switch (q.toLowerCase()) {
        'very high' || 'premium' => 5,
        'high' || 'enhanced' => 4,
        'normal' || 'default' => 3,
        'low' => 1,
        'very low' => 0,
        _ => 2,
      };

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

  /// Seams for the ranking tests. The ranking is the whole of the decision and
  /// it is pure arithmetic on what an engine reports, so it is worth testing
  /// without a device attached.
  @visibleForTesting
  static int localeRankForTest(String locale, List<String> wanted) =>
      _localeRank(locale, wanted);

  @visibleForTesting
  static int qualityRankForTest(String quality) => _qualityRank(quality);

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // ignore
    }
    speaking.value = null;
  }
}
