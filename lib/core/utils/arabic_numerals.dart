import 'package:flutter/services.dart';

/// Accepts numbers typed on an Arabic keyboard.
///
/// An Arabic keyboard emits Arabic-Indic digits (٠١٢٣٤٥٦٧٨٩), and a Persian or
/// Urdu layout emits the extended set (۰۱۲۳۴۵۶۷۸۹). `double.parse` understands
/// neither, so a patient typing their glucose reading in Arabic previously had
/// the characters filtered away as they typed and, if any survived, rejected as
/// invalid. They had no way to know why — the field simply refused them.
///
/// Both sets are normalised to ASCII before parsing. Storage and the wire
/// format stay ASCII; this is only about what a person is allowed to type.
class ArabicNumerals {
  ArabicNumerals._();

  /// U+0660–U+0669 — Arabic-Indic, the standard Arabic keyboard.
  static const _arabicIndic = '٠١٢٣٤٥٦٧٨٩';

  /// U+06F0–U+06F9 — Extended Arabic-Indic, used by Persian and Urdu layouts.
  /// Visually near-identical to the set above but different code points, so a
  /// converter that handles only one still rejects half the region's keyboards.
  static const _extended = '۰۱۲۳۴۵۶۷۸۹';

  /// Characters a numeric field may contain, in any script.
  ///
  /// Includes the Arabic decimal separator (U+066B ٫) and the Arabic thousands
  /// separator (U+066C ٬) — an Arabic keyboard produces these, not '.' and ','.
  static final RegExp allowedChars =
      RegExp('[0-9$_arabicIndic$_extended.,٫٬]');

  /// An input formatter that lets Arabic digits through instead of silently
  /// swallowing them. Drop-in replacement for
  /// `FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))`.
  static final TextInputFormatter inputFormatter =
      FilteringTextInputFormatter.allow(allowedChars);

  /// Converts any Arabic-Indic or extended digits in [input] to ASCII, and any
  /// Arabic decimal separator to '.'. Text that is already ASCII is unchanged.
  static String normalise(String input) {
    if (input.isEmpty) return input;
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        buffer.writeCharCode(0x30 + (rune - 0x0660)); // Arabic-Indic -> 0-9
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        buffer.writeCharCode(0x30 + (rune - 0x06F0)); // Extended -> 0-9
      } else if (rune == 0x066B) {
        buffer.write('.'); // Arabic decimal separator
      } else if (rune == 0x066C || rune == 0x002C) {
        // Thousands separators carry no value; dropping them means "1,250" and
        // "١٬٢٥٠" both parse rather than failing on the separator.
        continue;
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  /// [double.tryParse] that first accepts Arabic digits.
  static double? tryParseDouble(String input) =>
      double.tryParse(normalise(input).trim());

  /// [int.tryParse] that first accepts Arabic digits.
  static int? tryParseInt(String input) =>
      int.tryParse(normalise(input).trim());
}
