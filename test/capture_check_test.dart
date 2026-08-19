import 'package:flutter_test/flutter_test.dart';
import 'package:diafootcare_new/features/wound/capture/services/capture_check.dart';

/// The capture gate is the first thing in this app that can refuse a patient,
/// so its edges are pinned rather than assumed.
///
/// The thresholds are measured, not chosen: across 26 clinic photographs error
/// averages 18% below 30°, 40% between 30° and 40°, and 56% above 40°. Ten of
/// those 26 sat above 40°, so refusing is not a rare event and getting the
/// boundary wrong would either wave through bad photographs or block good ones.
void main() {
  group('CaptureCheck', () {
    test('only a proven bad angle blocks', () {
      expect(const CaptureCheck(CaptureVerdict.tooAngled, tiltDeg: 47).blocks,
          isTrue);

      // Everything else lets the patient through. A check that cannot see what
      // it is judging must not trap someone — a photograph with no label in it
      // is measured uncalibrated and flagged, not refused.
      for (final v in [
        CaptureVerdict.good,
        CaptureVerdict.marginal,
        CaptureVerdict.noRing,
        CaptureVerdict.unreadable,
      ]) {
        expect(CaptureCheck(v).blocks, isFalse, reason: '$v must not block');
      }
    });

    test('the bands are the measured ones', () {
      expect(CaptureChecker.warnAboveDeg, 30);
      expect(CaptureChecker.blockAboveDeg, 40);
    });

    test('every verdict has something to say, and says it differently', () {
      final titles = <String>{};
      final bodies = <String>{};
      for (final v in CaptureVerdict.values) {
        final c = CaptureCheck(v);
        expect(c.titleKey, isNotEmpty);
        expect(c.bodyKey, isNotEmpty);
        titles.add(c.titleKey);
        bodies.add(c.bodyKey);
      }
      // A shared key between two verdicts would tell the patient the same thing
      // whether they must retake or need not.
      expect(titles.length, CaptureVerdict.values.length);
      expect(bodies.length, CaptureVerdict.values.length);
    });

    test('only "good" counts as good', () {
      expect(const CaptureCheck(CaptureVerdict.good).isGood, isTrue);
      expect(const CaptureCheck(CaptureVerdict.marginal).isGood, isFalse);
      expect(const CaptureCheck(CaptureVerdict.noRing).isGood, isFalse);
    });

    test('an unreadable file is a verdict, not a crash', () async {
      final c = await const CaptureChecker().check('/no/such/photo.jpg');
      expect(c.verdict, CaptureVerdict.unreadable);
      expect(c.blocks, isFalse);
    });
  });
}
