import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The unit a glucose reading is *shown and entered* in.
///
/// **Storage is always mg/dL.** Readings already in the database are mg/dL, the
/// clinical thresholds in [GlucoseReading.status] are expressed in mg/dL, and
/// the server receives mg/dL — so converting at rest would silently reinterpret
/// every historical row and shift every threshold. The unit is therefore a
/// presentation choice only: values are converted on the way to the screen and
/// back again on input, and never in between.
///
/// mmol/L is the standard unit across most of Europe, and mg/dL across the US
/// and much of the Middle East; patients read whichever their meter shows, so
/// forcing one is a transcription-error risk.
enum GlucoseUnit {
  /// Milligrams per decilitre — the storage unit, and the app's default.
  mgdl,

  /// Millimoles per litre.
  mmoll;

  /// Exact molar mass conversion for glucose (180.156 g/mol → 18.0182).
  static const double _mgdlPerMmoll = 18.0182;

  String get label => this == GlucoseUnit.mgdl ? 'mg/dL' : 'mmol/L';

  /// Decimal places to show. mg/dL readings are whole numbers; mmol/L needs one
  /// decimal, since 1 mmol/L is ~18 mg/dL and rounding to a whole number would
  /// throw away clinically meaningful resolution.
  int get decimals => this == GlucoseUnit.mgdl ? 0 : 1;

  /// Convert a stored mg/dL value into this unit, for display.
  double fromMgdl(double mgdl) =>
      this == GlucoseUnit.mgdl ? mgdl : mgdl / _mgdlPerMmoll;

  /// Convert a value the user typed in this unit back to mg/dL, for storage.
  double toMgdl(double shown) =>
      this == GlucoseUnit.mgdl ? shown : shown * _mgdlPerMmoll;

  /// Formatted for display, without the unit label.
  String format(double mgdl) => fromMgdl(mgdl).toStringAsFixed(decimals);

  /// Formatted with the unit label — "112 mg/dL" / "6.2 mmol/L".
  String formatWithUnit(double mgdl) => '${format(mgdl)} $label';

  /// Plausible input range **in this unit**, used for validation. The bounds are
  /// the same physiological range either way (20–600 mg/dL), converted — so a
  /// mmol/L user is not rejected for typing a perfectly ordinary 6.2.
  double get minInput => fromMgdl(20);
  double get maxInput => fromMgdl(600);
}

/// The selected unit, persisted and observable.
///
/// A [ValueNotifier] rather than a plain getter so every screen showing a
/// reading redraws the moment the unit changes; a stale mg/dL number sitting
/// next to a "mmol/L" label would be a dangerous misread.
class GlucoseUnitPref {
  static const _key = 'glucose_unit';

  static final ValueNotifier<GlucoseUnit> unit =
      ValueNotifier<GlucoseUnit>(GlucoseUnit.mgdl);

  /// Loads the stored preference. Safe to call more than once.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_key);
      unit.value = v == 'mmoll' ? GlucoseUnit.mmoll : GlucoseUnit.mgdl;
    } catch (e) {
      // A missing preference is not a reason to fail: fall back to the storage
      // unit, which is also the safest default because no conversion applies.
      debugPrint('glucose unit preference unreadable, using mg/dL: $e');
      unit.value = GlucoseUnit.mgdl;
    }
  }

  static Future<void> set(GlucoseUnit u) async {
    unit.value = u;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, u == GlucoseUnit.mmoll ? 'mmoll' : 'mgdl');
    } catch (e) {
      debugPrint('could not persist glucose unit: $e');
    }
  }
}
