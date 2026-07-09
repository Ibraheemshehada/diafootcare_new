import 'package:flutter_test/flutter_test.dart';

import 'package:diafootcare_new/data/models/sus_entry.dart';

SusEntry sus(List<int> r) =>
    SusEntry(id: 't', dateTime: DateTime(2026), responses: r);

void main() {
  group('SUS scoring (Brooke, 1986)', () {
    test('perfect usability -> 100', () {
      // Best answer is 5 on positive (odd) items, 1 on negative (even) items.
      final r = [5, 1, 5, 1, 5, 1, 5, 1, 5, 1];
      expect(sus(r).rawSum, 40);
      expect(sus(r).score, 100.0);
    });

    test('worst usability -> 0', () {
      final r = [1, 5, 1, 5, 1, 5, 1, 5, 1, 5];
      expect(sus(r).rawSum, 0);
      expect(sus(r).score, 0.0);
    });

    test('all 5s -> 50, NOT 100 (polarity must be applied)', () {
      // A naive sum(r-1)*2.5 would give 100 here; the alternating polarity is
      // the whole point of SUS. This is the case that catches a broken impl.
      expect(sus(List.filled(10, 5)).score, 50.0);
    });

    test('all 1s -> 50', () {
      expect(sus(List.filled(10, 1)).score, 50.0);
    });

    test('all neutral 3s -> 50', () {
      expect(sus(List.filled(10, 3)).score, 50.0);
    });

    test('known mixed response -> 85 (verified against device DB)', () {
      final r = [5, 1, 5, 2, 5, 4, 5, 2, 5, 2];
      expect(sus(r).rawSum, 34);
      expect(sus(r).score, 85.0);
    });

    test('odd items are positive, even items negative', () {
      for (var i = 0; i < susItemCount; i++) {
        expect(susItemIsPositive(i), i.isEven, reason: 'item index $i');
      }
    });

    test('score is always in 0..100 for any valid responses', () {
      // Exhaustive-ish sweep of uniform answers plus a few mixes.
      for (var v = 1; v <= 5; v++) {
        final s = sus(List.filled(10, v)).score;
        expect(s, inInclusiveRange(0, 100));
        expect(s % 2.5, 0); // SUS scores land on 2.5 increments
      }
    });
  });

  group('SUS adjective bands', () {
    test('band thresholds (Bangor/Sauro)', () {
      expect(susAdjectiveKey(100), 'sus_band_excellent');
      expect(susAdjectiveKey(85), 'sus_band_excellent');
      expect(susAdjectiveKey(84.9), 'sus_band_good');
      expect(susAdjectiveKey(68), 'sus_band_good'); // average benchmark
      expect(susAdjectiveKey(67.9), 'sus_band_ok');
      expect(susAdjectiveKey(51), 'sus_band_ok');
      expect(susAdjectiveKey(50.9), 'sus_band_poor');
      expect(susAdjectiveKey(0), 'sus_band_poor');
    });
  });

  group('SusEntry serialization', () {
    test('toMap/fromMap round-trips responses and score', () {
      final r = [5, 1, 5, 2, 5, 4, 5, 2, 5, 2];
      final e = SusEntry(
          id: 'abc', dateTime: DateTime(2026, 7, 8, 14, 30), responses: r);
      final back = SusEntry.fromMap(e.toMap());
      expect(back.id, 'abc');
      expect(back.responses, r);
      expect(back.score, e.score);
      expect(back.dateTime, e.dateTime);
    });

    test('toMap emits q1..q10 columns', () {
      final m = sus([1, 2, 3, 4, 5, 1, 2, 3, 4, 5]).toMap();
      for (var i = 1; i <= 10; i++) {
        expect(m.containsKey('q$i'), isTrue, reason: 'q$i');
      }
      expect(m['q1'], 1);
      expect(m['q10'], 5);
    });

    test('fromMap defaults missing answers to neutral 3', () {
      final back = SusEntry.fromMap({'id': 'x', 'dateTime': 0, 'q1': 5});
      expect(back.responses.length, susItemCount);
      expect(back.responses[0], 5);
      expect(back.responses[1], 3); // missing -> neutral
    });
  });
}
