import 'package:flutter_test/flutter_test.dart';

import 'package:diafootcare_new/data/models/wound_entry.dart';
import 'package:diafootcare_new/features/history/viewmodel/history_viewmodel.dart';

WoundEntry w(DateTime d, double len, double wid) => WoundEntry(
      date: d,
      imagePath: '',
      lengthCm: len,
      widthCm: wid,
      inflammation: 'None',
      progressPct: 0,
    );

void main() {
  group('computeTrend bucketing', () {
    test('empty entries -> empty series', () {
      expect(computeTrend(const [], TrendRange.daily).isEmpty, isTrue);
    });

    test('zero-area baseline -> empty series (percent change undefined)', () {
      // Mirrors the real device data: uncalibrated wounds with 0x0 cm.
      final e = [w(DateTime(2026, 7, 6), 0, 0), w(DateTime(2026, 7, 8), 0, 0)];
      expect(computeTrend(e, TrendRange.daily).isEmpty, isTrue);
    });

    test('always emits exactly 7 buckets, oldest -> newest', () {
      final now = DateTime(2026, 7, 8);
      final e = [w(DateTime(2026, 7, 8), 2, 2)];
      for (final r in TrendRange.values) {
        final s = computeTrend(e, r, now: now);
        expect(s.values.length, 7, reason: '$r values');
        expect(s.bucketStarts.length, 7, reason: '$r starts');
        for (var i = 1; i < 7; i++) {
          expect(s.bucketStarts[i].isAfter(s.bucketStarts[i - 1]), isTrue,
              reason: '$r bucket $i must be newer than ${i - 1}');
        }
      }
    });

    test('daily: area halves -> +50% on that day, carried forward', () {
      final now = DateTime(2026, 7, 8);
      final e = [
        w(DateTime(2026, 7, 4, 9), 4, 4), // baseline area 16
        w(DateTime(2026, 7, 6, 9), 4, 2), // area 8 -> 50% reduction
      ];
      final s = computeTrend(e, TrendRange.daily, now: now);
      // buckets: Jul 2,3,4,5,6,7,8
      expect(s.bucketStarts.first, DateTime(2026, 7, 2));
      expect(s.bucketStarts.last, DateTime(2026, 7, 8));
      expect(s.values[0], 0); // before any data
      expect(s.values[2], 0); // Jul 4 = baseline day -> 0% vs itself
      expect(s.values[3], 0); // Jul 5 carries Jul 4
      expect(s.values[4], closeTo(50, 1e-9)); // Jul 6
      expect(s.values[5], closeTo(50, 1e-9)); // Jul 7 carried
      expect(s.values[6], closeTo(50, 1e-9)); // Jul 8 carried
    });

    test('daily: same-day entries are averaged', () {
      final now = DateTime(2026, 7, 8);
      final e = [
        w(DateTime(2026, 7, 7, 1), 4, 4), // baseline 16
        w(DateTime(2026, 7, 8, 1), 4, 4), // 16
        w(DateTime(2026, 7, 8, 20), 2, 2), // 4  -> avg of day = 10
      ];
      final s = computeTrend(e, TrendRange.daily, now: now);
      // (16 - 10) / 16 * 100 = 37.5
      expect(s.values.last, closeTo(37.5, 1e-9));
    });

    test('weekly buckets start on Monday and step by 7 days', () {
      // 2026-07-08 is a Wednesday.
      expect(DateTime(2026, 7, 8).weekday, DateTime.wednesday);
      final s = computeTrend([w(DateTime(2026, 7, 8), 2, 2)], TrendRange.weekly,
          now: DateTime(2026, 7, 8));
      expect(s.bucketStarts.last, DateTime(2026, 7, 6)); // Monday
      expect(s.bucketStarts.last.weekday, DateTime.monday);
      expect(s.bucketStarts.first, DateTime(2026, 5, 25)); // 6 weeks earlier
      for (final b in s.bucketStarts) {
        expect(b.weekday, DateTime.monday);
      }
    });

    test('weekly: entries in the same week share a bucket', () {
      final now = DateTime(2026, 7, 8); // week of Mon Jul 6
      final e = [
        w(DateTime(2026, 6, 29), 4, 4), // week of Jun 29, baseline 16
        w(DateTime(2026, 7, 6), 4, 4), // week of Jul 6
        w(DateTime(2026, 7, 8), 2, 2), // same week -> avg 10
      ];
      final s = computeTrend(e, TrendRange.weekly, now: now);
      expect(s.values.last, closeTo(37.5, 1e-9));
    });

    test('monthly: crosses a year boundary correctly', () {
      final now = DateTime(2026, 2, 15);
      final s = computeTrend([w(DateTime(2026, 2, 1), 2, 2)],
          TrendRange.monthly, now: now);
      expect(s.bucketStarts.first, DateTime(2025, 8)); // 6 months back
      expect(s.bucketStarts.last, DateTime(2026, 2));
    });

    test('monthly step-back does not skip short months (Mar 31 -> Feb)', () {
      // Naive `subtract(Duration(days: 30))` from Mar 31 lands in Mar/Feb
      // inconsistently; calendar arithmetic must give Feb.
      final b = trendStepBack(DateTime(2026, 3), TrendRange.monthly, 1);
      expect(b, DateTime(2026, 2));
      expect(trendStepBack(DateTime(2026, 1), TrendRange.monthly, 1),
          DateTime(2025, 12));
    });

    test('measurement older than the window seeds the carry-forward', () {
      // Baseline Jan (16), improved to 8 in Feb (50%). Window = Jul..Jan? No:
      // now = Dec, window is Jun..Dec, so Feb's 50% is *before* the window.
      final now = DateTime(2026, 12, 15);
      final e = [
        w(DateTime(2026, 1, 10), 4, 4), // baseline 16
        w(DateTime(2026, 2, 10), 4, 2), // 8 -> 50%
      ];
      final s = computeTrend(e, TrendRange.monthly, now: now);
      expect(s.bucketStarts.first, DateTime(2026, 6));
      // Every in-window bucket should carry the 50% already achieved,
      // not reset to 0.
      for (final v in s.values) {
        expect(v, closeTo(50, 1e-9));
      }
    });

    test('wound growing back yields a negative percent', () {
      final now = DateTime(2026, 7, 8);
      final e = [
        w(DateTime(2026, 7, 7), 2, 2), // baseline 4
        w(DateTime(2026, 7, 8), 4, 2), // 8 -> -100%
      ];
      final s = computeTrend(e, TrendRange.daily, now: now);
      expect(s.values.last, closeTo(-100, 1e-9));
    });
  });
}
