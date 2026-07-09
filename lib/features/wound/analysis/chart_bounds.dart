/// Y-axis bounds for the wound-area progress chart.
///
/// fl_chart maps a value to a pixel with `(value - minY) / (maxY - minY)`. If
/// `maxY == minY` that denominator is zero, so every point lands at an infinite
/// pixel offset — which is exactly the "BOTTOM OVERFLOWED BY Infinity PIXELS"
/// render error, followed by a thrown build (the sanitized error screen). This
/// happened whenever every recorded wound area was 0 — e.g. uncalibrated
/// captures where segmentation never produced a length/width, so the whole
/// series is 0×0 cm.
///
/// [chartYBounds] guarantees a finite, strictly-increasing range (`max > min`,
/// no NaN/Infinity) whatever the input, so the chart always renders.
class ChartYBounds {
  final double min;
  final double max;
  const ChartYBounds(this.min, this.max);

  @override
  bool operator ==(Object other) =>
      other is ChartYBounds && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() => 'ChartYBounds($min, $max)';
}

/// Padded, non-degenerate Y bounds for [values] (wound areas). Mirrors the
/// original padding (20% headroom, floor a little below the smallest value but
/// never below 0) but can never return a zero-height or non-finite span.
ChartYBounds chartYBounds(Iterable<double> values) {
  const fallbackSpan = 100.0;
  final finite = values.where((v) => v.isFinite).toList();
  if (finite.isEmpty) return const ChartYBounds(0, fallbackSpan);

  final maxV = finite.reduce((a, b) => a > b ? a : b);
  final minV = finite.reduce((a, b) => a < b ? a : b);

  var maxY = ((maxV * 1.2) / 100).ceil() * 100.0;
  final minY = (minV * 0.8).clamp(0.0, double.infinity).toDouble();

  // Guarantee a visible span so fl_chart never divides by zero.
  if (maxY <= minY) maxY = minY + fallbackSpan;
  return ChartYBounds(minY, maxY);
}
