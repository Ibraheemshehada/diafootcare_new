import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:diafootcare_new/features/wound/analysis/screens/ai_result_screen.dart';
import 'package:diafootcare_new/features/wound/analysis/viewmodel/analysis_result.dart';

/// The tissue card must not show confidence figures.
///
/// It used to: a bar and a percentage per class, under a sentence explaining
/// that each class carries its own tuned threshold. Clinicians and patients read
/// "Necrosis 36%" as *some necrosis* — when 36% against a 60% threshold means
/// the model did **not** find necrosis. A number below its threshold and one
/// above it look identical; the only thing separating them was the note nobody
/// read.
///
/// So this asserts the absence of something, which is unusual but is the point:
/// the numbers are easy to add back by habit, and nothing else would catch it.
/// The probabilities remain in the model, the database and the sync payload —
/// they belong in the study data, not on a screen read over a patient's foot.
void main() {
  TissueFinding f(String type, double p, double threshold) => TissueFinding(
        type: type,
        probability: p,
        isPresent: p >= threshold,
        thresholdUsed: threshold,
      );

  /// The live result from `teston app .jpeg`: granulation and callus found,
  /// necrosis nowhere near its threshold but high enough to alarm anyone who
  /// saw the figure.
  final findings = [
    f('granulation', 0.826, 0.43),
    f('callus', 0.768, 0.45),
    f('necrosis', 0.356, 0.60),
    f('slough', 0.139, 0.63),
    f('epithelial', 0.070, 0.09),
  ];

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TissueBreakdown(findings: findings),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no percentage is rendered anywhere in the card', (tester) async {
    await pump(tester);

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .toList();

    expect(texts, isNotEmpty, reason: 'the card rendered nothing at all');

    for (final s in texts) {
      expect(s.contains('%'), isFalse,
          reason: 'a confidence figure is back on screen: "$s"');
    }

    // 36% is the one that matters: necrosis, well under its threshold. If any
    // form of it reaches the screen, someone will read it as partial necrosis.
    expect(find.textContaining('36'), findsNothing);
    expect(find.textContaining('0.36'), findsNothing);
  });

  testWidgets('no progress bar carries the probability visually',
      (tester) async {
    await pump(tester);

    // A bar says "36% of the way along" just as plainly as the digits do.
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('every class is still listed, found or not', (tester) async {
    await pump(tester);

    // Removing the numbers must not remove the finding. All five classes stay,
    // so an absent tissue is stated rather than implied by omission.
    for (final name in const [
      'Granulation',
      'Callus',
      'Necrosis',
      'Slough',
      'Epithelial',
    ]) {
      expect(find.text(name), findsOneWidget, reason: '$name is missing');
    }

    // Two found, three not. The icons carry it too, but the words are what a
    // patient actually reads.
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    expect(find.byIcon(Icons.remove_circle_outline), findsNWidgets(3));
  });
}
