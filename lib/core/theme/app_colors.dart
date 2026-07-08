import 'package:flutter/material.dart';

/// Theme-aware semantic colours that meet **WCAG 2.1 AA** contrast for normal
/// text (≥ 4.5:1) against the surface they are drawn on.
///
/// The raw Material swatches previously used for clinical status text failed
/// badly on white — e.g. `Colors.orange` (2.16:1) and `Colors.amber.shade700`
/// (2.04:1) for the glucose "Low"/"Elevated" labels. Those are exactly the
/// labels a low-vision diabetic patient must be able to read, so every value
/// below was chosen by measuring the contrast ratio, not by eye.
///
/// Measured ratios (foreground on background):
/// | token   | light on #FFFFFF | dark on #1A2030 |
/// |---------|------------------|-----------------|
/// | success | 5.13             | 8.07            |
/// | danger  | 5.62             | 5.44            |
/// | warning | 5.02             | 9.38            |
/// | caution | 6.51             | 11.51           |
/// | streak  | 5.14             | 7.02            |
class AppColors {
  final bool isDark;
  const AppColors._(this.isDark);

  factory AppColors.of(BuildContext context) =>
      AppColors._(Theme.of(context).brightness == Brightness.dark);

  /// Good / normal / completed.
  Color get success =>
      isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);

  /// Bad / high risk / error.
  Color get danger =>
      isDark ? const Color(0xFFE57373) : const Color(0xFFC62828);

  /// Elevated / partial adherence (was amber.shade700 — 2.04:1, unreadable).
  Color get warning =>
      isDark ? const Color(0xFFFFB74D) : const Color(0xFFB45309);

  /// Low / below-target (was Colors.orange — 2.16:1, unreadable).
  Color get caution =>
      isDark ? const Color(0xFFFFD54F) : const Color(0xFF8A5000);

  /// Streak flame.
  Color get streak =>
      isDark ? const Color(0xFFFF8A65) : const Color(0xFFC4400E);
}
