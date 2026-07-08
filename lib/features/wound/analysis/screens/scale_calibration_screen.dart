import 'dart:io';
import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

/// Reference-object calibration.
///
/// A single photo has no inherent scale, so to report wound size in real cm the
/// user places an object of KNOWN length in the frame (the long edge of any
/// bank/ID card is a universal 8.56 cm reference) and taps its two ends here.
/// We compute `pixelsPerCm` in ORIGINAL-image pixel space and return it; the
/// AI service bakes EXIF orientation the same way, so the scale lines up.
///
/// Returns the computed `pixelsPerCm` via `Navigator.pop`, or `null` if skipped.
class ScaleCalibrationScreen extends StatefulWidget {
  final String imagePath;
  const ScaleCalibrationScreen({super.key, required this.imagePath});

  @override
  State<ScaleCalibrationScreen> createState() => _ScaleCalibrationScreenState();
}

class _RefOption {
  final String labelKey; // translation key
  final double? cm; // null => custom
  const _RefOption(this.labelKey, this.cm);
}

class _ScaleCalibrationScreenState extends State<ScaleCalibrationScreen> {
  static const _prefsKey = 'calib_last_ref_cm';
  static const _options = <_RefOption>[
    _RefOption('ref_card_long_edge', 8.56),
    _RefOption('ref_card_short_edge', 5.398),
    _RefOption('ref_custom', null),
  ];

  Uint8List? _displayBytes; // baked, downscaled image for display
  int _iw = 0, _ih = 0; // baked (oriented) pixel dimensions
  bool _loading = true;

  // Tap points in the image box's widget-space coordinates.
  final List<Offset> _points = [];
  Size _box = Size.zero; // current size of the image area

  int _selected = 0;
  final _customCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _prepareImage();
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _prepareImage() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('decode failed');
      final baked = img.bakeOrientation(decoded);
      _iw = baked.width;
      _ih = baked.height;
      final disp =
          baked.width > 1080 ? img.copyResize(baked, width: 1080) : baked;
      _displayBytes = Uint8List.fromList(img.encodeJpg(disp, quality: 90));

      final prefs = await SharedPreferences.getInstance();
      final lastCm = prefs.getDouble(_prefsKey);
      if (lastCm != null) {
        final idx = _options.indexWhere((o) => o.cm == lastCm);
        if (idx >= 0) {
          _selected = idx;
        } else {
          _selected = _options.length - 1; // custom
          _customCtrl.text = lastCm.toString();
        }
      }
    } catch (_) {
      // leave _displayBytes null -> show error state
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double? get _referenceCm {
    final opt = _options[_selected];
    if (opt.cm != null) return opt.cm;
    return double.tryParse(_customCtrl.text.trim());
  }

  /// Geometry of the BoxFit.contain image inside [_box].
  ({double scale, double dx, double dy}) _fit() {
    final scale = min(_box.width / _iw, _box.height / _ih);
    final dispW = _iw * scale, dispH = _ih * scale;
    return (
      scale: scale,
      dx: (_box.width - dispW) / 2,
      dy: (_box.height - dispH) / 2,
    );
  }

  void _onTapDown(TapDownDetails d) {
    if (_box == Size.zero) return;
    final f = _fit();
    final x = d.localPosition.dx.clamp(f.dx, _box.width - f.dx);
    final y = d.localPosition.dy.clamp(f.dy, _box.height - f.dy);
    setState(() {
      if (_points.length >= 2) _points.clear();
      _points.add(Offset(x, y));
    });
  }

  double? _computePixelsPerCm() {
    if (_points.length < 2 || _box == Size.zero) return null;
    final cm = _referenceCm;
    if (cm == null || cm <= 0) return null;
    final f = _fit();
    Offset toImg(Offset p) =>
        Offset((p.dx - f.dx) / f.scale, (p.dy - f.dy) / f.scale);
    final distPx = (toImg(_points[0]) - toImg(_points[1])).distance;
    if (distPx <= 0) return null;
    return distPx / cm;
  }

  Future<void> _confirm() async {
    final ppc = _computePixelsPerCm();
    if (ppc == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKey, _referenceCm!);
    if (mounted) Navigator.pop<double?>(context, ppc);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('set_scale'.tr(), style: TextStyle(fontSize: 18.sp)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop<double?>(context, null),
            child: Text('skip'.tr()),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _displayBytes == null
              ? Center(child: Text('could_not_load_image'.tr()))
              : Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 4.h),
                      child: Text(
                        'calib_instruction'.tr(),
                        style: t.textTheme.bodyMedium?.copyWith(fontSize: 13.sp),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(12.w),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            _box = Size(
                                constraints.maxWidth, constraints.maxHeight);
                            return GestureDetector(
                              onTapDown: _onTapDown,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.memory(_displayBytes!,
                                      fit: BoxFit.contain),
                                  CustomPaint(
                                    painter: _MarkerPainter(
                                      List.of(_points),
                                      t.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    _controls(t),
                  ],
                ),
    );
  }

  Widget _controls(ThemeData t) {
    final ready = _points.length == 2 &&
        (_referenceCm != null && _referenceCm! > 0);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 12.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('reference_length'.tr(),
                style: t.textTheme.labelLarge?.copyWith(fontSize: 13.sp)),
            SizedBox(height: 6.h),
            Wrap(
              spacing: 8.w,
              children: List.generate(_options.length, (i) {
                return ChoiceChip(
                  label: Text(
                    _options[i].labelKey.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.sp),
                  ),
                  selected: _selected == i,
                  onSelected: (_) => setState(() => _selected = i),
                );
              }),
            ),
            if (_options[_selected].cm == null) ...[
              SizedBox(height: 8.h),
              TextField(
                controller: _customCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  labelText: 'reference_length_cm'.tr(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            SizedBox(height: 10.h),
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: FilledButton(
                onPressed: ready ? _confirm : null,
                child: Text(
                  _points.length < 2
                      ? 'tap_two_ends'.tr()
                      : 'use_this_scale'.tr(),
                  style: TextStyle(fontSize: 15.sp),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkerPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  _MarkerPainter(this.points, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = color;
    final line = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    if (points.length == 2) canvas.drawLine(points[0], points[1], line);
    for (final p in points) {
      canvas.drawCircle(p, 7, Paint()..color = Colors.white);
      canvas.drawCircle(p, 5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _MarkerPainter old) =>
      old.points != points || old.color != color;
}
