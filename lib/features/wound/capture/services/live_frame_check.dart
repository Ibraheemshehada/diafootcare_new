import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

import '../../analysis/services/ring_detector.dart';

/// Reads the calibration ring out of a live camera frame.
///
/// Guidance has to arrive while the phone is still in the air. Telling a patient
/// afterwards that the photograph was too angled is telling them to undress the
/// wound again — and ten of 26 clinic photographs were past 40°, where measured
/// error reaches 56%, so this is the common case rather than the rare one.
///
/// The work is deliberately small: frames arrive faster than they can be
/// analysed, so most are dropped and the survivor is shrunk before anything
/// looks at it. What the ring detector needs is the shape and the hue of a mark
/// that spans a fifth of the frame; it does not need megapixels.
class LiveFrameCheck {
  const LiveFrameCheck();

  /// Frames are analysed at this width. The ring is 150–250 px across in a
  /// 1200 px photograph, so at 320 it is still 40–65 px — plenty for an
  /// ellipse, and a twentieth of the pixels.
  static const int analyseWidth = 320;

  /// Converts one camera frame and reads the ring, or null.
  ///
  /// Returns null rather than throwing on an unexpected format: a preview that
  /// stops guiding is bad, a preview that crashes the camera is worse.
  static RingDetection? read(CameraImage frame) {
    try {
      final rgb = _toImage(frame);
      if (rgb == null) return null;
      return const RingDetector().detect(rgb);
    } catch (_) {
      return null;
    }
  }

  /// YUV420 (Android) and BGRA8888 (iOS) into an [img.Image], downscaled on the
  /// way rather than after — converting every pixel of a full preview frame and
  /// then throwing 95% away is most of the cost of doing this at all.
  static img.Image? _toImage(CameraImage f) {
    if (f.format.group == ImageFormatGroup.bgra8888) {
      final full = img.Image.fromBytes(
        width: f.width,
        height: f.height,
        bytes: f.planes[0].bytes.buffer,
        order: img.ChannelOrder.bgra,
      );
      return _fit(full);
    }
    if (f.format.group != ImageFormatGroup.yuv420 || f.planes.length < 3) {
      return null;
    }

    final step = (f.width / analyseWidth).ceil().clamp(1, 8);
    final w = f.width ~/ step, h = f.height ~/ step;
    final out = img.Image(width: w, height: h);

    final y = f.planes[0], u = f.planes[1], v = f.planes[2];
    final uvRow = u.bytesPerRow;
    final uvPix = u.bytesPerPixel ?? 1;

    for (var j = 0; j < h; j++) {
      final sy = j * step;
      final yRow = sy * y.bytesPerRow;
      final uvOff = (sy >> 1) * uvRow;
      for (var i = 0; i < w; i++) {
        final sx = i * step;
        final yy = y.bytes[yRow + sx];
        final uvIdx = uvOff + (sx >> 1) * uvPix;
        final uu = u.bytes[uvIdx] - 128;
        final vv = v.bytes[uvIdx] - 128;
        out.setPixelRgb(
          i,
          j,
          (yy + 1.402 * vv).round().clamp(0, 255),
          (yy - 0.344136 * uu - 0.714136 * vv).round().clamp(0, 255),
          (yy + 1.772 * uu).round().clamp(0, 255),
        );
      }
    }
    return out;
  }

  static img.Image _fit(img.Image src) => src.width > analyseWidth
      ? img.copyResize(src,
          width: analyseWidth,
          height: (src.height * analyseWidth / src.width).round(),
          interpolation: img.Interpolation.nearest)
      : src;
}

/// What the live preview should be telling the patient right now.
enum LiveGuide {
  /// No printed label in view. The commonest starting state, and the one where
  /// telling someone to "hold the phone flatter" would be meaningless.
  noLabel,

  /// Label found, but the camera is turned too far from the wound.
  tooAngled,

  /// Close. Worth saying so, because the last few degrees are the hardest.
  almost,

  /// Square enough to measure.
  ready,
}

extension LiveGuideText on LiveGuide {
  /// Short enough to read at arm's length while holding a phone over a foot.
  String get key => switch (this) {
        LiveGuide.noLabel => 'live_no_label',
        LiveGuide.tooAngled => 'live_too_angled',
        LiveGuide.almost => 'live_almost',
        LiveGuide.ready => 'live_ready',
      };

  bool get canShoot => this == LiveGuide.ready || this == LiveGuide.noLabel;
}

/// Bands the tilt into advice. Same numbers as the still-photo gate, because a
/// preview that passes what the next screen refuses would be worse than no
/// preview at all.
LiveGuide guideFor(RingDetection? ring) {
  if (ring == null) return LiveGuide.noLabel;
  if (ring.tiltDeg > 40) return LiveGuide.tooAngled;
  if (ring.tiltDeg > 30) return LiveGuide.almost;
  return LiveGuide.ready;
}
