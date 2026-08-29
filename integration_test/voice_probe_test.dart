import 'package:diafootcare_new/core/services/voice_assistant_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:integration_test/integration_test.dart';

/// What voices this device actually has, and which one we end up using.
///
/// Not an assertion about quality — nothing automated can hear. This prints the
/// engine's own answer so a complaint about how the voice sounds can be
/// investigated with facts: which engine, which voice, what quality the system
/// reports, and whether the language resolved at all.
///
/// Android reports a quality per voice (very low → very high). The app was
/// asking for none of it and taking whatever the engine handed back, which on
/// many devices is the smallest embedded voice rather than the best installed
/// one.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('list the engines, languages and voices', (tester) async {
    final tts = FlutterTts();

    final engines = await tts.getEngines;
    // ignore: avoid_print
    print('ENGINES: $engines');
    // ignore: avoid_print
    print('DEFAULT ENGINE: ${await tts.getDefaultEngine}');

    final langs = (await tts.getLanguages as List?) ?? [];
    final interesting =
        langs.where((l) => '$l'.startsWith('ar') || '$l'.startsWith('en'));
    // ignore: avoid_print
    print('LANGUAGES(${langs.length}) ar/en: ${interesting.join(", ")}');

    for (final tag in ['ar-SA', 'ar', 'en-US']) {
      // ignore: avoid_print
      print('AVAILABLE $tag: ${await tts.isLanguageAvailable(tag)}');
    }

    // ignore: avoid_print
    print('DEFAULT VOICE: ${await tts.getDefaultVoice}');

    final voices = (await tts.getVoices as List?) ?? [];
    for (final v in voices) {
      final m = Map<String, dynamic>.from(v as Map);
      final locale = '${m['locale']}';
      if (!locale.startsWith('ar') && !locale.startsWith('en')) continue;
      // ignore: avoid_print
      print('VOICE ${m['name']} | $locale | quality=${m['quality']} '
          '| latency=${m['latency']} | network=${m['network_required']}');
    }
    // ignore: avoid_print
    print('VOICE COUNT total=${voices.length}');
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('the app picks a voice for each language', (tester) async {
    // What the service actually settles on, per language, on this device.
    // Speaking is the only way to make it choose.
    for (final code in ['en', 'ar']) {
      final ok = await VoiceAssistantService.I
          .speak('one two three', languageCode: code);
      // ignore: avoid_print
      print('CHOSEN[$code] spoke=$ok voice=${VoiceAssistantService.I.selectedVoice}');
      await VoiceAssistantService.I.stop();

      expect(ok, isTrue, reason: 'no voice was usable for $code');
      final v = VoiceAssistantService.I.selectedVoice;
      expect(v, isNotNull);
      // The failure this replaces: Arabic text read by an English voice.
      if (code == 'ar') {
        expect(v!.contains('en-'), isFalse,
            reason: 'an English voice was chosen to read Arabic: $v');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
