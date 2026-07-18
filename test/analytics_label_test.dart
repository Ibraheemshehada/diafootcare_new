import 'package:diafootcare_new/core/services/analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The study groups engagement by this label, so how it is derived is part of
/// the data contract — not an implementation detail.
void main() {
  group('route label for an unnamed route', () {
    test('extracts the screen name from a builder closure type', () {
      expect(
        AnalyticsRouteObserver.labelForBuilderType('(BuildContext) => ConsentScreen'),
        '(unnamed) ConsentScreen',
      );
      expect(
        AnalyticsRouteObserver.labelForBuilderType('(BuildContext) => TermsScreen'),
        '(unnamed) TermsScreen',
      );
    });

    test('tolerates spacing variations', () {
      expect(
        AnalyticsRouteObserver.labelForBuilderType('(BuildContext)=>HomeScreen'),
        '(unnamed) HomeScreen',
      );
    });

    // Under release obfuscation the type string may carry no usable identifier.
    // One shared bucket is correct there: inventing a label per build would
    // split one screen across several rows in the study data.
    test('falls back to a single bucket when nothing identifiable is present', () {
      for (final raw in ['Closure', '', '(BuildContext) => 123', 'minified']) {
        expect(AnalyticsRouteObserver.labelForBuilderType(raw), '(unnamed)',
            reason: 'unparseable "$raw" must not become its own label');
      }
    });

    test('never returns the raw closure string', () {
      const raw = '(BuildContext) => ConsentScreen';
      expect(AnalyticsRouteObserver.labelForBuilderType(raw), isNot(raw));
    });
  });
}
