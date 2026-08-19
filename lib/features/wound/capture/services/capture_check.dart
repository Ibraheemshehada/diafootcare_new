import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../analysis/services/ring_detector.dart';

/// Judges a photograph before it is analysed, and says what to do about it.
///
/// The angle is the one thing a patient can fix in the moment and the single
/// best predictor of a bad measurement. Across 26 clinic photographs, error
/// correlates with tilt at **r = +0.479**:
///
/// | Tilt | Mean error |
/// |---|---|
/// | 20–30° | 18.1% |
/// | 30–40° | 39.6% |
/// | **>40°** | **55.8%** |
///
/// The physics is not the intuitive part. The ring's *major* axis is
/// unforeshortened, so the SCALE survives tilt — but the wound does not: an
/// extent lying along the tilt direction is compressed by `cos θ`, which is −6%
/// at 20°, **−23% at 40°** and −36% at 50°. Part of the under-measurement first
/// blamed on segmentation is this.
///
/// Ten of those 26 photographs sat above 40°, so this is not a rare case.
enum CaptureVerdict {
  /// Square enough. Below 30°, error averages 18%.
  good,

  /// 30–40°: allowed, but the patient is told it can be better.
  marginal,

  /// Above 40°, where error triples. **Refused** — the only verdict that blocks,
  /// and only because the ring proves the angle rather than a guess about it.
  tooAngled,

  /// No ring in frame. The measurement will be uncalibrated and is flagged as
  /// approximate, but nothing here can prove the angle, so nothing is refused.
  noRing,

  /// The photograph could not be read at all.
  unreadable,
}

class CaptureCheck {
  final CaptureVerdict verdict;
  final double? tiltDeg;
  final double? pixelsPerCm;
  final bool? usedSmallLabel;

  const CaptureCheck(this.verdict,
      {this.tiltDeg, this.pixelsPerCm, this.usedSmallLabel});

  /// Only [CaptureVerdict.tooAngled] stops the flow. A patient must never be
  /// trapped by a check that cannot see what it is judging — so a missing ring
  /// warns and lets them through.
  bool get blocks => verdict == CaptureVerdict.tooAngled;

  bool get isGood => verdict == CaptureVerdict.good;

  String get titleKey => switch (verdict) {
        CaptureVerdict.good => 'capture_angle_good_title',
        CaptureVerdict.marginal => 'capture_angle_marginal_title',
        CaptureVerdict.tooAngled => 'capture_angle_blocked_title',
        CaptureVerdict.noRing => 'capture_no_ring_title',
        CaptureVerdict.unreadable => 'capture_unreadable_title',
      };

  String get bodyKey => switch (verdict) {
        CaptureVerdict.good => 'capture_angle_good_body',
        CaptureVerdict.marginal => 'capture_angle_marginal_body',
        CaptureVerdict.tooAngled => 'capture_angle_blocked_body',
        CaptureVerdict.noRing => 'capture_no_ring_body',
        CaptureVerdict.unreadable => 'capture_unreadable_body',
      };

  String get title => titleKey.tr();
  String get body => bodyKey.tr();
}

/// Runs the ring detector over a captured file.
class CaptureChecker {
  const CaptureChecker();

  /// Thresholds are the measured bands above, not round numbers.
  static const double warnAboveDeg = 30;
  static const double blockAboveDeg = 40;

  Future<CaptureCheck> check(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      // Decoding and scanning a 12-megapixel photograph is real work; off the
      // UI isolate so the preview stays responsive while it runs.
      return await compute(_run, bytes);
    } catch (e) {
      debugPrint('⚠️  Capture check failed: $e');
      return const CaptureCheck(CaptureVerdict.unreadable);
    }
  }
}

CaptureCheck _run(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return const CaptureCheck(CaptureVerdict.unreadable);
  final image = img.bakeOrientation(decoded);

  final ring = const RingDetector().detect(image);
  if (ring == null) return const CaptureCheck(CaptureVerdict.noRing);

  final t = ring.tiltDeg;
  final verdict = t > CaptureChecker.blockAboveDeg
      ? CaptureVerdict.tooAngled
      : t > CaptureChecker.warnAboveDeg
          ? CaptureVerdict.marginal
          : CaptureVerdict.good;

  return CaptureCheck(verdict,
      tiltDeg: t,
      pixelsPerCm: ring.pixelsPerCm,
      usedSmallLabel: ring.isSmall);
}
