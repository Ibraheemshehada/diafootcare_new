import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'ring_detector.dart';

/// Draws what the model actually saw over the photograph it saw it in.
///
/// Until now the app reported "2.4 × 1.1 cm" with nothing behind it, and a
/// clinician had no way to tell a correct measurement from one taken off the
/// printed label — a failure that happened in 16 of 42 small-label photographs
/// and once agreed with the clinician's own figure by coincidence. An overlay
/// makes that visible in one glance instead of invisible forever.
///
/// It is also how every wrong conclusion in this project was caught: the swapped
/// reference rows, the drape read as a ring, the label measured as granulation.
/// Each was found by looking at the mask, not at the number.
class OverlayRenderer {
  const OverlayRenderer();

  /// Wound fill and outline. Red at 45% lets the tissue read through, which is
  /// what makes an under-segmented boundary obvious rather than hidden.
  static const _woundFill = [220, 40, 40];
  static const _woundEdge = [255, 60, 60];
  static const _ringEdge = [40, 220, 120];

  /// The longest side of the saved overlay. Full resolution would be several
  /// megabytes per scan to store and sync for no gain — the point is to be
  /// looked at, and it is looked at on a phone.
  static const int maxSide = 900;

  /// Renders and saves beside the photograph, returning the path, or null if
  /// anything went wrong. A missing overlay must never cost the measurement:
  /// this is an explanation of the result, not part of it.
  Future<String?> render({
    required img.Image source,
    required List<List<bool>> mask,
    required RingDetection? ring,
    required String forImagePath,
  }) async {
    try {
      final bytes = await compute(
        _renderPng,
        _Job(
          img.encodeJpg(source, quality: 92),
          mask,
          ring?.centerX,
          ring?.centerY,
          ring?.majorPx,
          ring?.minorPx,
        ),
      );
      if (bytes == null) return null;
      final dir = p.dirname(forImagePath);
      final stem = p.basenameWithoutExtension(forImagePath);
      final out = p.join(dir, '${stem}_overlay.png');
      await File(out).writeAsBytes(bytes);
      debugPrint('🖼️  Overlay written -> $out');
      return out;
    } catch (e) {
      debugPrint('⚠️  Overlay rendering failed: $e');
      return null;
    }
  }
}

class _Job {
  final Uint8List jpg;
  final List<List<bool>> mask;
  final double? cx, cy, major, minor;
  const _Job(this.jpg, this.mask, this.cx, this.cy, this.major, this.minor);
}

Uint8List? _renderPng(_Job job) {
  final src = img.decodeJpg(job.jpg);
  if (src == null) return null;

  final scale = src.width > OverlayRenderer.maxSide || src.height > OverlayRenderer.maxSide
      ? OverlayRenderer.maxSide / max(src.width, src.height)
      : 1.0;
  final out = scale < 1.0
      ? img.copyResize(src,
          width: (src.width * scale).round(),
          height: (src.height * scale).round(),
          interpolation: img.Interpolation.average)
      : src.clone();

  final mh = job.mask.length;
  if (mh == 0) return img.encodePng(out);
  final mw = job.mask[0].length;
  final w = out.width, h = out.height;

  bool at(int x, int y) {
    final my = (y * mh / h).floor().clamp(0, mh - 1);
    final mx = (x * mw / w).floor().clamp(0, mw - 1);
    return job.mask[my][mx];
  }

  // Fill first, then trace the edge over it, so the boundary stays legible where
  // the wound and the fill are both red.
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (!at(x, y)) continue;
      final px = out.getPixel(x, y);
      out.setPixelRgb(
        x,
        y,
        (px.r * 0.55 + OverlayRenderer._woundFill[0] * 0.45).round(),
        (px.g * 0.55 + OverlayRenderer._woundFill[1] * 0.45).round(),
        (px.b * 0.55 + OverlayRenderer._woundFill[2] * 0.45).round(),
      );
    }
  }
  final edge = max(2, (w / 300).round());
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      if (!at(x, y)) continue;
      if (at(x - 1, y) && at(x + 1, y) && at(x, y - 1) && at(x, y + 1)) continue;
      for (var dy = -edge; dy <= edge; dy++) {
        for (var dx = -edge; dx <= edge; dx++) {
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;
          out.setPixelRgb(nx, ny, OverlayRenderer._woundEdge[0],
              OverlayRenderer._woundEdge[1], OverlayRenderer._woundEdge[2]);
        }
      }
    }
  }

  // The ring, so the scale the numbers came from is visible too. A measurement
  // shown without the thing that gave it its units cannot be checked.
  if (job.cx != null && job.major != null && job.minor != null) {
    final cx = job.cx! * scale, cy = job.cy! * scale;
    final a = job.major! * scale / 2, b = job.minor! * scale / 2;
    final t = max(2, (w / 400).round());
    for (var i = 0; i < 720; i++) {
      final th = i * pi / 360;
      for (var k = -t; k <= t; k++) {
        final x = (cx + (a + k) * cos(th)).round();
        final y = (cy + (b + k) * sin(th)).round();
        if (x < 0 || x >= w || y < 0 || y >= h) continue;
        out.setPixelRgb(x, y, OverlayRenderer._ringEdge[0],
            OverlayRenderer._ringEdge[1], OverlayRenderer._ringEdge[2]);
      }
    }
  }

  return img.encodePng(out);
}
