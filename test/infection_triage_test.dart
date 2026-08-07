import 'package:flutter_test/flutter_test.dart';
import 'package:diafootcare_new/features/wound/analysis/services/infection_triage.dart';

/// Covers the IWGDF/IDSA fusion rules in infection_triage.dart.
///
/// The safety properties are the point of these tests: absence of pain must
/// never reassure, two reported signs must overrule a quiet image, and a loud
/// image on its own must ask for a retake rather than raise an alarm.
void main() {
  const none = InfectionSigns();

  group('image banding', () {
    test('splits at the measured cut-offs', () {
      expect(zoneFor(0.00), ImageZone.low);
      expect(zoneFor(0.29), ImageZone.low);
      expect(zoneFor(kZoneLowMax), ImageZone.uncertain); // boundary is inclusive up
      expect(zoneFor(0.50), ImageZone.uncertain);
      expect(zoneFor(0.79), ImageZone.uncertain);
      expect(zoneFor(kZoneHighMin), ImageZone.high);
      expect(zoneFor(1.00), ImageZone.high);
    });
  });

  group('systemic symptoms outrank everything', () {
    test('urgent even when the image is quiet and nothing else is reported', () {
      final r = triage(
        infectionProbability: 0.01,
        signs: const InfectionSigns(systemicUnwell: true),
      );
      expect(r.outcome, TriageOutcome.urgent);
      expect(r.basis, 'systemic');
      // Already being sent for care, so the deep-infection caveat is redundant.
      expect(r.needsDeepInfectionCaveat, isFalse);
    });

    test('urgent regardless of image zone', () {
      for (final p in [0.05, 0.5, 0.95]) {
        expect(
          triage(
            infectionProbability: p,
            signs: const InfectionSigns(systemicUnwell: true),
          ).outcome,
          TriageOutcome.urgent,
        );
      }
    });
  });

  group('purulent discharge is a standalone criterion', () {
    test('routes to a clinician on its own, with a quiet image', () {
      final r = triage(
        infectionProbability: 0.02,
        signs: const InfectionSigns(purulentDischarge: true),
      );
      expect(r.outcome, TriageOutcome.seeClinician);
      expect(r.basis, 'purulent_discharge');
    });
  });

  group('two or more signs meet the IWGDF bar', () {
    test('quiet image + two reported signs still sees a clinician', () {
      // The safety property that matters most: the checklist can overrule the
      // model, because the model is the least reliable channel here.
      final r = triage(
        infectionProbability: 0.05,
        signs: const InfectionSigns(warmth: true, swelling: true),
      );
      expect(r.outcome, TriageOutcome.seeClinician);
      expect(r.zone, ImageZone.low);
      expect(r.basis, 'symptoms_only');
      expect(r.signCount, 2);
    });

    test('suggestive image + one reported sign reaches two', () {
      final r = triage(
        infectionProbability: 0.9,
        signs: const InfectionSigns(warmth: true),
      );
      expect(r.outcome, TriageOutcome.seeClinician);
      expect(r.basis, 'image_and_symptoms');
      expect(r.signCount, 2);
    });

    test('uncertain image + two reported signs sees a clinician', () {
      final r = triage(
        infectionProbability: 0.55,
        signs: const InfectionSigns(warmth: true, tenderness: true),
      );
      expect(r.outcome, TriageOutcome.seeClinician);
      expect(r.signCount, 2);
    });

    test('an uncertain image contributes no sign of its own', () {
      // 0.55 plus a single sign must NOT reach the bar; if an uncertain score
      // ever starts casting a vote, false alarms come straight back.
      final r = triage(
        infectionProbability: 0.55,
        signs: const InfectionSigns(warmth: true),
      );
      expect(r.outcome, TriageOutcome.monitor);
      expect(r.signCount, 1);
    });
  });

  group('a loud image alone asks for a retake, not an alarm', () {
    test('high probability with nothing reported', () {
      final r = triage(infectionProbability: 0.95, signs: none);
      expect(r.outcome, TriageOutcome.recheckPhoto);
      expect(r.basis, 'image_only');
      expect(r.signCount, 1);
    });
  });

  group('neuropathy safety: absence of pain never reassures', () {
    test('no tenderness does not cancel other signs', () {
      final withPain = triage(
        infectionProbability: 0.5,
        signs: const InfectionSigns(warmth: true, swelling: true, tenderness: true),
      );
      final withoutPain = triage(
        infectionProbability: 0.5,
        signs: const InfectionSigns(warmth: true, swelling: true),
      );
      // Losing the pain answer must not soften the outcome — a neuropathic
      // patient can feel nothing over a serious infection.
      expect(withPain.outcome, TriageOutcome.seeClinician);
      expect(withoutPain.outcome, TriageOutcome.seeClinician);
    });

    test('a "no" answer can never lower the sign count', () {
      final r = triage(
        infectionProbability: 0.9,
        signs: const InfectionSigns(warmth: true, tenderness: false),
      );
      expect(r.signCount, 2); // image + warmth; the "no" subtracted nothing
      expect(r.outcome, TriageOutcome.seeClinician);
    });
  });

  group('quiet on both channels', () {
    test('reports no signs', () {
      final r = triage(infectionProbability: 0.05, signs: none);
      expect(r.outcome, TriageOutcome.noSigns);
      expect(r.signCount, 0);
      expect(r.basis, 'none');
    });

    test('still carries the deep-infection caveat', () {
      // Osteomyelitis is invisible to both channels, so "no signs" must never
      // be presented as an all-clear.
      final r = triage(infectionProbability: 0.05, signs: none);
      expect(r.needsDeepInfectionCaveat, isTrue);
    });

    test('one sign alone is monitor, not an alarm', () {
      final r = triage(
        infectionProbability: 0.05,
        signs: const InfectionSigns(swelling: true),
      );
      expect(r.outcome, TriageOutcome.monitor);
      expect(r.basis, 'single_sign');
    });

    test('uncertain image with nothing reported is monitor', () {
      final r = triage(infectionProbability: 0.5, signs: none);
      expect(r.outcome, TriageOutcome.monitor);
      expect(r.basis, 'image_uncertain');
    });
  });

  group('InfectionSigns helpers', () {
    test('counts only the three local signs', () {
      const s = InfectionSigns(
        warmth: true,
        swelling: true,
        tenderness: true,
        purulentDischarge: true, // standalone, not part of the local count
        systemicUnwell: true, // emergency, not part of the local count
      );
      expect(s.localSignCount, 3);
      expect(s.isEmpty, isFalse);
    });

    test('isEmpty when nothing is reported', () {
      expect(const InfectionSigns().isEmpty, isTrue);
    });
  });

  group('no input can produce a silent all-clear when signs are reported', () {
    test('every combination of two local signs reaches a clinician', () {
      const combos = [
        InfectionSigns(warmth: true, swelling: true),
        InfectionSigns(warmth: true, tenderness: true),
        InfectionSigns(swelling: true, tenderness: true),
      ];
      for (final s in combos) {
        for (final p in [0.0, 0.31, 0.79, 0.99]) {
          expect(
            triage(infectionProbability: p, signs: s).outcome,
            TriageOutcome.seeClinician,
            reason: 'two local signs must always escalate (p=$p)',
          );
        }
      }
    });
  });
}
