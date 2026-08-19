import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Finds the printed calibration ring and reports the scale it implies.
///
/// The label carries an annulus of known outer diameter — **20 mm** on the
/// standard cyan label, **15 mm** on the small magenta one used on toes. Scale is
/// then a pure ratio, `pixelsPerCm = outerDiameterPx / ringCm`, needing no camera
/// intrinsics and no assumption about how far the phone was held.
///
/// That assumption is what this replaces. Without a ring the app divided the
/// frame width by an assumed 12 cm, so a real 1.4 cm wound was reported as 0.9 cm
/// purely because of how the photograph was framed. Measured on 239 clinic
/// photographs, the ring holds the measurement to **±1.8–5%** while camera
/// distance varies by a factor of two.
///
/// Ported from the detector validated on those photographs
/// (`clinical_validation/scripts/ring_detect.py`). Every filter below exists
/// because something in the clinic defeated the version without it, and the
/// comments say which.
class RingDetector {
  /// Printed outer diameters, in centimetres.
  static const double standardCm = 2.0;
  static const double smallCm = 1.5;

  /// Detection runs on a downscaled copy. The ring spans 150–250 px in a
  /// 1200 px-wide clinic photograph, so at 640 it is still 80–130 px across —
  /// far more than the measurement needs, at a fifth of the pixels. Morphology
  /// over 1.9 M pixels on a phone is the part that would otherwise be felt.
  static const int _workWidth = 640;

  /// Below this the候 candidate is noise rather than a printed mark.
  static const int _minAreaPx = 120;

  const RingDetector();

  /// Returns null when no ring is found — which is a real answer, not a failure:
  /// the caller must then say the measurement is uncalibrated rather than invent
  /// a scale.
  RingDetection? detect(img.Image src) {
    final scale = src.width > _workWidth ? _workWidth / src.width : 1.0;
    final im = scale < 1.0
        ? img.copyResize(src,
            width: _workWidth,
            height: (src.height * scale).round(),
            interpolation: img.Interpolation.average)
        : src;

    final w = im.width, h = im.height;
    final cyan = Uint8List(w * h);
    final magenta = Uint8List(w * h);
    final any = Uint8List(w * h);

    for (int y = 0, i = 0; y < h; y++) {
      for (int x = 0; x < w; x++, i++) {
        final p = im.getPixel(x, y);
        final hsv = _hsv(p.r.toDouble(), p.g.toDouble(), p.b.toDouble());
        final hue = hsv[0], sat = hsv[1], val = hsv[2];
        // Cyan ink: the 20 mm standard label.
        final isCyan = hue >= 80 && hue <= 115 && sat >= 60 && val >= 40;
        // Magenta ink: the 15 mm small label. The band is deliberately narrow
        // and demands high saturation — a wider one swallowed inflamed skin,
        // producing 525,000 "magenta" pixels in one photograph and burying the
        // real ring under a blob. Printed ink sits near hue 160 at saturation
        // no skin reaches.
        final isMag = hue >= 145 && hue <= 175 && sat >= 110 && val >= 50;
        if (isCyan) cyan[i] = 1;
        if (isMag) magenta[i] = 1;
        if (isCyan || isMag) any[i] = 1;
      }
    }

    // Open BEFORE close, and close only gently. A 9×9 close sealed the hole of
    // the small ring whenever it sat far enough from the camera, turning the
    // annulus into a disc — which the hole test then correctly rejected. The
    // detector was destroying the very feature it looks for.
    var mask = _open(any, w, h, 3);
    mask = _close(mask, w, h, 2);

    final labels = Int32List(w * h);
    final comps = _components(mask, w, h, labels);
    if (comps.isEmpty) return null;

    _Candidate? best;
    for (final c in comps) {
      if (c.area < _minAreaPx) continue;
      final ax = _axes(c, labels, w);
      if (ax == null) continue;
      final major = ax[0], minor = ax[1];
      if (major <= 0) continue;

      final round = minor / major;
      // A ring projects to an ellipse. Anything this elongated is a colour
      // patch, a sleeve or a shadow.
      if (round < 0.5) continue;

      // A ring photographed for measurement fills a sane share of the frame.
      final frac = major / max(w, h);
      if (frac <= 0.02 || frac >= 0.45) continue;

      // THE decisive test: the calibration mark is an ANNULUS. A blue surgical
      // drape, a sleeve or a shadow is solid. Sample the middle — if it is still
      // ink, this is a filled blob. Without this the detector locked onto a
      // drape in the background and reported a 1102 px "ring", i.e. a foot
      // photographed 2 cm wide.
      if (_centreIsInk(mask, w, h, c.cx, c.cy, minor)) continue;

      // The annulus covers only part of its own ellipse; a disc covers all of
      // it. Combined with the hole test this separates ring from blob twice
      // over, which is what the clinic photographs needed.
      final ellipseArea = pi * (major / 2) * (minor / 2);
      final fill = c.area / ellipseArea;
      if (fill < 0.12 || fill > 0.95) continue;

      // Rank by roundness, not size. Picking the largest blob favours skin
      // regions that survive the filters by luck; the calibration mark is the
      // roundest thing in frame with a clean hole.
      final score = round * min(1.0, c.area / 600.0);
      if (best == null || score > best.score) {
        best = _Candidate(score, c, major, minor);
      }
    }
    if (best == null) return null;

    // Which label was it? Sample the ring's own ink, not the whole frame —
    // hue is the size key, and reading it wrong scales every measurement by 4/3.
    var cyanPx = 0, magPx = 0;
    final b = best;
    for (int y = 0, i = 0; y < h; y++) {
      for (int x = 0; x < w; x++, i++) {
        if (labels[i] != b.comp.id) continue;
        if (cyan[i] == 1) cyanPx++;
        if (magenta[i] == 1) magPx++;
      }
    }
    final isSmall = magPx > cyanPx;

    final inv = scale < 1.0 ? 1.0 / scale : 1.0;
    final majorFull = b.major * inv;
    final minorFull = b.minor * inv;
    final ringCm = isSmall ? smallCm : standardCm;

    return RingDetection(
      centerX: b.comp.cx * inv,
      centerY: b.comp.cy * inv,
      majorPx: majorFull,
      minorPx: minorFull,
      isSmall: isSmall,
      pixelsPerCm: majorFull / ringCm,
      // The ring's major axis is unforeshortened, so the SCALE survives tilt.
      // The wound does not: an extent along the tilt direction is compressed by
      // cos θ — −6% at 20°, −23% at 40°, −36% at 50°. Measured on 26 clinic
      // photographs, error correlates with tilt at r = +0.479, rising from 18%
      // below 30° to 56% above 40°. That is what the capture gate acts on.
      tiltDeg: acos(min(1.0, minorFull / majorFull)) * 180 / pi,
    );
  }

  // ---------------------------------------------------------------------------

  /// OpenCV's HSV convention: H in 0–179, S and V in 0–255, so the thresholds
  /// above are the same numbers the validated Python detector uses.
  static List<double> _hsv(double r, double g, double b) {
    final mx = max(r, max(g, b)), mn = min(r, min(g, b));
    final d = mx - mn;
    double h;
    if (d == 0) {
      h = 0;
    } else if (mx == r) {
      h = 30 * (((g - b) / d) % 6);
    } else if (mx == g) {
      h = 30 * ((b - r) / d + 2);
    } else {
      h = 30 * ((r - g) / d + 4);
    }
    if (h < 0) h += 180;
    return [h, mx == 0 ? 0 : 255 * d / mx, mx];
  }

  /// Binary erode/dilate with a square kernel, done as two 1-D passes. Exact for
  /// a square structuring element and O(w·h·k) instead of O(w·h·k²) — the
  /// difference between milliseconds and a visible pause on a phone.
  static Uint8List _morph(Uint8List src, int w, int h, int r, bool dilate) {
    final tmp = Uint8List(w * h);
    final out = Uint8List(w * h);
    for (int y = 0; y < h; y++) {
      final row = y * w;
      for (int x = 0; x < w; x++) {
        var hit = dilate ? 0 : 1;
        for (int k = -r; k <= r; k++) {
          final nx = x + k;
          final v = (nx < 0 || nx >= w) ? (dilate ? 0 : 1) : src[row + nx];
          if (dilate ? v == 1 : v == 0) {
            hit = dilate ? 1 : 0;
            break;
          }
        }
        tmp[row + x] = hit;
      }
    }
    for (int x = 0; x < w; x++) {
      for (int y = 0; y < h; y++) {
        var hit = dilate ? 0 : 1;
        for (int k = -r; k <= r; k++) {
          final ny = y + k;
          final v = (ny < 0 || ny >= h) ? (dilate ? 0 : 1) : tmp[ny * w + x];
          if (dilate ? v == 1 : v == 0) {
            hit = dilate ? 1 : 0;
            break;
          }
        }
        out[y * w + x] = hit;
      }
    }
    return out;
  }

  static Uint8List _open(Uint8List m, int w, int h, int r) =>
      _morph(_morph(m, w, h, r, false), w, h, r, true);

  static Uint8List _close(Uint8List m, int w, int h, int r) =>
      _morph(_morph(m, w, h, r, true), w, h, r, false);

  static List<_Comp> _components(Uint8List m, int w, int h, Int32List labels) {
    final comps = <_Comp>[];
    final stack = <int>[];
    var next = 0;
    for (int i = 0; i < m.length; i++) {
      if (m[i] == 0 || labels[i] != 0) continue;
      final id = ++next;
      var area = 0;
      var sx = 0.0, sy = 0.0;
      stack
        ..clear()
        ..add(i);
      labels[i] = id;
      while (stack.isNotEmpty) {
        final p = stack.removeLast();
        final y = p ~/ w, x = p % w;
        area++;
        sx += x;
        sy += y;
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            final ny = y + dy, nx = x + dx;
            if (ny < 0 || ny >= h || nx < 0 || nx >= w) continue;
            final q = ny * w + nx;
            if (m[q] == 1 && labels[q] == 0) {
              labels[q] = id;
              stack.add(q);
            }
          }
        }
      }
      comps.add(_Comp(id, area, sx / area, sy / area));
    }
    return comps;
  }

  /// Outer extents along the region's principal axes.
  ///
  /// For an annulus this is exactly the outer diameter — which is what the
  /// printed size refers to — without needing a conic fit. It is also what the
  /// wound measurement uses, so ring and wound are measured by the same rule.
  static List<double>? _axes(_Comp c, Int32List labels, int w) {
    double sxx = 0, sxy = 0, syy = 0;
    var n = 0;
    for (int i = 0; i < labels.length; i++) {
      if (labels[i] != c.id) continue;
      final dx = (i % w) - c.cx, dy = (i ~/ w) - c.cy;
      sxx += dx * dx;
      sxy += dx * dy;
      syy += dy * dy;
      n++;
    }
    if (n < 12) return null;
    sxx /= n;
    sxy /= n;
    syy /= n;
    final theta = 0.5 * atan2(2 * sxy, sxx - syy);
    final ca = cos(theta), sa = sin(theta);
    double uMin = double.infinity, uMax = -double.infinity;
    double vMin = double.infinity, vMax = -double.infinity;
    for (int i = 0; i < labels.length; i++) {
      if (labels[i] != c.id) continue;
      final dx = (i % w) - c.cx, dy = (i ~/ w) - c.cy;
      final u = dx * ca + dy * sa, v = -dx * sa + dy * ca;
      if (u < uMin) uMin = u;
      if (u > uMax) uMax = u;
      if (v < vMin) vMin = v;
      if (v > vMax) vMax = v;
    }
    final a = uMax - uMin, b = vMax - vMin;
    return [max(a, b), min(a, b)];
  }

  static bool _centreIsInk(
      Uint8List m, int w, int h, double cx, double cy, double minor) {
    final ix = cx.round(), iy = cy.round();
    if (ix < 0 || ix >= w || iy < 0 || iy >= h) return true;
    final r = max(2, (minor * 0.15).round());
    var sum = 0, count = 0;
    for (int y = max(0, iy - r); y <= min(h - 1, iy + r); y++) {
      for (int x = max(0, ix - r); x <= min(w - 1, ix + r); x++) {
        sum += m[y * w + x];
        count++;
      }
    }
    // >23% ink in the middle means a filled blob, not an annulus. (The Python
    // detector's `patch.mean() > 60` on a 0–255 mask is the same threshold.)
    return count == 0 || sum / count > 0.235;
  }
}

/// What the ring says about this photograph.
class RingDetection {
  final double centerX, centerY;
  final double majorPx, minorPx;
  final bool isSmall;

  /// The whole point: true scale in ORIGINAL-image pixels per centimetre.
  final double pixelsPerCm;

  /// How far the label plane is turned away from the camera, in degrees.
  final double tiltDeg;

  const RingDetection({
    required this.centerX,
    required this.centerY,
    required this.majorPx,
    required this.minorPx,
    required this.isSmall,
    required this.pixelsPerCm,
    required this.tiltDeg,
  });

  double get ringCm => isSmall ? RingDetector.smallCm : RingDetector.standardCm;

  @override
  String toString() => 'RingDetection(${isSmall ? "small" : "standard"}, '
      '${majorPx.toStringAsFixed(0)}px, ${pixelsPerCm.toStringAsFixed(1)} px/cm, '
      'tilt ${tiltDeg.toStringAsFixed(0)}°)';
}

class _Comp {
  final int id, area;
  final double cx, cy;
  const _Comp(this.id, this.area, this.cx, this.cy);
}

class _Candidate {
  final double score;
  final _Comp comp;
  final double major, minor;
  const _Candidate(this.score, this.comp, this.major, this.minor);
}
