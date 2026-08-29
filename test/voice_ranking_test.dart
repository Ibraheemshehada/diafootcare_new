import 'package:flutter_test/flutter_test.dart';

import 'package:diafootcare_new/core/services/voice_assistant_service.dart';

/// Which voice the app picks, given what an engine offers.
///
/// The service used to ask for `ar-SA` — a tag no Android engine lists. Google
/// ships Arabic as `ar`, with voices named `ar-xa-x-ard-local` and similar, and
/// `isLanguageAvailable('ar-SA')` still answered true because Android matches
/// loosely. The engine then chose for itself, which is how a patient ends up
/// with a voice nobody picked and nobody can explain.
///
/// The lists below are the real output of `getVoices` on a device, copied from
/// integration_test/voice_probe_test.dart, so this is ranking the same data the
/// app will see rather than an invented shape.
void main() {
  // Lower is better, -1 means no match.
  group('locale ranking', () {
    test('Arabic voices match the Arabic request', () {
      for (final locale in ['ar', 'ar-XA', 'ar_SA']) {
        expect(VoiceAssistantService.localeRankForTest(locale, const ['ar']),
            greaterThanOrEqualTo(0),
            reason: '$locale should be usable for Arabic');
      }
    });

    test('English voices do not match an Arabic request', () {
      // The failure that mattered: an English voice reading Arabic text aloud.
      for (final locale in ['en-US', 'en-GB', 'en-AU', 'en-IN']) {
        expect(VoiceAssistantService.localeRankForTest(locale, const ['ar']),
            -1,
            reason: '$locale must never be chosen to read Arabic');
      }
    });

    test('en-US is preferred over other English variants', () {
      const wanted = ['en-us', 'en-gb', 'en'];
      final us = VoiceAssistantService.localeRankForTest('en-US', wanted);
      final gb = VoiceAssistantService.localeRankForTest('en-GB', wanted);
      final au = VoiceAssistantService.localeRankForTest('en-AU', wanted);
      expect(us, lessThan(gb));
      expect(gb, lessThan(au));
    });

    test('Arabic is not matched by an unrelated locale', () {
      expect(VoiceAssistantService.localeRankForTest('fr-FR', const ['ar']), -1);
      expect(VoiceAssistantService.localeRankForTest('', const ['ar']), -1);
    });
  });

  group('quality ranking', () {
    test('Android wording is ordered', () {
      final ranks = [
        'very high', 'high', 'normal', 'low', 'very low',
      ].map(VoiceAssistantService.qualityRankForTest).toList();
      for (var i = 1; i < ranks.length; i++) {
        expect(ranks[i], lessThan(ranks[i - 1]),
            reason: 'quality order broke at index $i');
      }
    });

    test('Apple wording is ordered', () {
      expect(VoiceAssistantService.qualityRankForTest('premium'),
          greaterThan(VoiceAssistantService.qualityRankForTest('enhanced')));
      expect(VoiceAssistantService.qualityRankForTest('enhanced'),
          greaterThan(VoiceAssistantService.qualityRankForTest('default')));
    });

    test('an unknown word sits mid-table, not at the bottom', () {
      // An engine that words this differently should not have every one of its
      // voices ranked below a genuinely poor one.
      final unknown = VoiceAssistantService.qualityRankForTest('excellent');
      expect(unknown, greaterThan(VoiceAssistantService.qualityRankForTest('low')));
      expect(unknown, lessThan(VoiceAssistantService.qualityRankForTest('high')));
    });
  });
}
