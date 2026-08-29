import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:integration_test/integration_test.dart';

/// Plays the same sentence through every Arabic voice on the device, in turn,
/// naming each one before it speaks.
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

  testWidgets('audition every Arabic voice', (tester) async {
    final tts = FlutterTts();
    await tts.awaitSpeakCompletion(true);
    await tts.setSpeechRate(0.45);
    await tts.setPitch(1.0);

    final voices = ((await tts.getVoices as List?) ?? [])
        .map((v) => Map<String, dynamic>.from(v as Map))
        .where((v) => '${v['locale']}'.toLowerCase().startsWith('ar'))
        .toList();

    expect(voices, isNotEmpty, reason: 'no Arabic voice is installed');

    // A sentence from the app rather than a test phrase, so the judgement is
    // made on the words a patient will actually hear.
    const sample = 'افحص قدميك كل يوم، وتأكد من عدم وجود جروح أو احمرار.';

    for (final v in voices) {
      // ignore: avoid_print
      print('AUDITION ${v['name']} | ${v['locale']} | '
          'quality=${v['quality']} | network=${v['network_required']}');
      await tts.setVoice({
        'name': '${v['name']}',
        'locale': '${v['locale']}',
        if (v['identifier'] != null) 'identifier': '${v['identifier']}',
      });
      await tts.speak(sample);
      // A gap, so two voices are not confused for one another.
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }

    // ignore: avoid_print
    print('AUDITION done: ${voices.length} Arabic voices');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
