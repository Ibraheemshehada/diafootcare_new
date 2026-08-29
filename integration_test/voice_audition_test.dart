import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:integration_test/integration_test.dart';

/// Plays a sentence through every Arabic and English voice on the device, in
/// turn, numbering each one before it speaks.
///
/// Nothing automated can judge how a voice sounds, and the engine is no help:
/// on the emulator every Arabic voice reports `quality: high`, so the ranking
/// has nothing to separate them and the winner among equals is arbitrary. A
/// person has to listen and say which one.
///
///     flutter test integration_test/voice_audition_test.dart -d <device>
///
/// Then set the winner as the preferred voice in VoiceAssistantService, ahead
/// of the quality ordering.
///
/// Run it with the volume up — the audio comes out of the machine running the
/// emulator, not out of the test log.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('audition every Arabic and English voice', (tester) async {
    final tts = FlutterTts();
    await tts.awaitSpeakCompletion(true);
    await tts.setSpeechRate(0.45);
    await tts.setPitch(1.0);

    final all = ((await tts.getVoices as List?) ?? [])
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();

    // Sentences from the app rather than test phrases, so the judgement is made
    // on the words a patient will actually hear.
    const samples = {
      'ar': 'افحص قدميك كل يوم، وتأكد من عدم وجود جروح أو احمرار.',
      'en': 'Check your feet every day for cuts, redness or swelling.',
    };

    // Installed voices only. A streaming voice may sound better and is not the
    // one this app should pick: it goes silent in a clinic with no signal.
    var n = 0;
    for (final lang in ['ar', 'en']) {
      final voices = all
          .where((v) =>
              '${v['locale']}'.toLowerCase().startsWith(lang) &&
              '${v['network_required']}' != '1')
          .toList();
      expect(voices, isNotEmpty, reason: 'no installed $lang voice');

      for (final v in voices) {
        n++;
        // The number is the point: say "number 7 was the clear one" and it can
        // be pinned without anybody having to transcribe a voice id by ear.
        // ignore: avoid_print
        print('AUDITION #$n  ${v['name']}  |  ${v['locale']}  |  '
            'quality=${v['quality']}');
        await tts.setVoice({
          'name': '${v['name']}',
          'locale': '${v['locale']}',
          if (v['identifier'] != null) 'identifier': '${v['identifier']}',
        });
        await tts.speak(samples[lang]!);
        // A gap, so two voices are not confused for one another.
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
    }

    // ignore: avoid_print
    print('AUDITION done: $n installed voices');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
