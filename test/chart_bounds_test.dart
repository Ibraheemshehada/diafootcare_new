import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diafootcare_new/features/wound/analysis/chart_bounds.dart';

void main() {
  group('chartYBounds — never degenerate or non-finite', () {
    test('all-zero areas (the crash case) -> non-zero span', () {
      // This is the real bug: uncalibrated 0×0 cm captures made every area 0,
      // so minY==maxY==0 and fl_chart divided by a zero span.
      final b = chartYBounds([0, 0, 0, 0]);
      expect(b.min, 0);
      expect(b.max, greaterThan(b.min));
      expect(b.max.isFinite, isTrue);
    });

    test('single zero value -> non-zero span', () {
      final b = chartYBounds([0]);
      expect(b.max, greaterThan(b.min));
    });

    test('empty input -> sensible default range', () {
      final b = chartYBounds(const []);
      expect(b.min, 0);
      expect(b.max, greaterThan(0));
    });

    test('all equal non-zero values -> still a visible span', () {
      final b = chartYBounds([500, 500, 500]);
      expect(b.max, greaterThan(b.min));
    });

    test('NaN / Infinity are ignored', () {
      final b = chartYBounds([double.nan, double.infinity, 200, 400]);
      expect(b.min.isFinite, isTrue);
      expect(b.max.isFinite, isTrue);
      expect(b.max, greaterThan(b.min));
    });

    test('only non-finite values -> default range, still finite', () {
      final b = chartYBounds([double.nan, double.infinity]);
      expect(b.min.isFinite, isTrue);
      expect(b.max.isFinite, isTrue);
      expect(b.max, greaterThan(b.min));
    });

    test('normal range keeps headroom above the max', () {
      // 20% headroom rounded up to the next 100.
      final b = chartYBounds([100, 850]);
      expect(b.max, greaterThanOrEqualTo(850 * 1.2));
      expect(b.min, lessThanOrEqualTo(100));
    });

    test('bounds are always finite and strictly increasing (fuzz)', () {
      final samples = <List<double>>[
        [0],
        [0, 0],
        [1],
        [0.0001, 0.0002],
        [1e9, 1e9],
        [-5, -5], // shouldn't happen for areas, but must not blow up
        [3, 3, 3, 3, 3],
      ];
      for (final s in samples) {
        final b = chartYBounds(s);
        expect(b.min.isFinite, isTrue, reason: '$s min finite');
        expect(b.max.isFinite, isTrue, reason: '$s max finite');
        expect(b.max, greaterThan(b.min), reason: '$s max>min');
      }
    });
  });

  group('regression: progress chart with all-zero areas renders', () {
    // Reproduces the reported crash: uncalibrated 0×0 cm wounds made every area
    // 0, so the old minY==maxY==0 range drove fl_chart to divide by zero
    // ("OVERFLOWED BY Infinity PIXELS" then a thrown build). With chartYBounds
    // the same data must render with no exception.
    testWidgets('LineChart of all-zero areas does not throw', (tester) async {
      final b = chartYBounds([0, 0, 0]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 220,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: 2,
                    minY: b.min,
                    maxY: b.max,
                    lineBarsData: [
                      LineChartBarData(
                        spots: const [
                          FlSpot(0, 0),
                          FlSpot(1, 0),
                          FlSpot(2, 0),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
