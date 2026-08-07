import 'package:flutter_test/flutter_test.dart';
import 'package:diafootcare_new/core/utils/arabic_numerals.dart';

void main() {
  group('accepts numbers typed on an Arabic keyboard', () {
    test('Arabic-Indic digits parse', () {
      expect(ArabicNumerals.tryParseDouble('١٢٥'), 125);
      expect(ArabicNumerals.tryParseDouble('٦٫٢'), closeTo(6.2, 1e-9));
      expect(ArabicNumerals.tryParseInt('٩٠'), 90);
    });

    test('extended (Persian/Urdu) digits parse — a different code range', () {
      expect(ArabicNumerals.tryParseDouble('۱۲۵'), 125);
      expect(ArabicNumerals.tryParseDouble('۶.۲'), closeTo(6.2, 1e-9));
    });

    test('ASCII still works, unchanged', () {
      expect(ArabicNumerals.tryParseDouble('125'), 125);
      expect(ArabicNumerals.tryParseDouble('6.2'), closeTo(6.2, 1e-9));
    });

    test('mixed scripts parse — a half-switched keyboard is common', () {
      expect(ArabicNumerals.tryParseDouble('١2٥'), 125);
    });

    test('the Arabic decimal separator ٫ becomes a point', () {
      expect(ArabicNumerals.normalise('٦٫٢'), '6.2');
    });

    test('thousands separators are dropped, not treated as decimals', () {
      // "1,250" must be 1250, never 1.250 — reading that as 1.25 mmol/L instead
      // of 1250 would be a clinically dangerous misparse.
      expect(ArabicNumerals.tryParseDouble('1,250'), 1250);
      expect(ArabicNumerals.tryParseDouble('١٬٢٥٠'), 1250);
    });

    test('rubbish is still rejected rather than coerced', () {
      expect(ArabicNumerals.tryParseDouble('abc'), isNull);
      expect(ArabicNumerals.tryParseDouble(''), isNull);
      expect(ArabicNumerals.tryParseDouble('١٢٣ mg'), isNull);
    });

    test('surrounding whitespace is tolerated', () {
      expect(ArabicNumerals.tryParseDouble('  ١٢٥  '), 125);
    });

    test('the input filter admits Arabic digits and separators', () {
      for (final c in '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹0123456789.٫'.split('')) {
        expect(ArabicNumerals.allowedChars.hasMatch(c), isTrue,
            reason: 'the filter must not swallow "$c" as it is typed');
      }
      expect(ArabicNumerals.allowedChars.hasMatch('م'), isFalse);
    });
  });
}
