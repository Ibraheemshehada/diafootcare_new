/// A single blood-glucose reading (mg/dL) with the context it was taken in.
class GlucoseReading {
  final String id;
  final double value; // mg/dL
  final DateTime dateTime;
  final String tag; // 'fasting' | 'post_meal' | 'random'

  GlucoseReading({
    required this.id,
    required this.value,
    required this.dateTime,
    required this.tag,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'value': value,
        'dateTime': dateTime.millisecondsSinceEpoch,
        'tag': tag,
      };

  factory GlucoseReading.fromMap(Map<String, dynamic> m) => GlucoseReading(
        id: m['id'] as String,
        value: (m['value'] as num).toDouble(),
        dateTime: DateTime.fromMillisecondsSinceEpoch(m['dateTime'] as int),
        tag: (m['tag'] as String?) ?? 'random',
      );

  /// Clinical category of this reading. Thresholds follow common ADA guidance
  /// (mg/dL) and depend on whether it was a fasting reading.
  /// Returns one of: 'low', 'normal', 'elevated', 'high'.
  GlucoseStatus get status {
    if (value < 70) return GlucoseStatus.low;
    if (tag == 'fasting') {
      if (value <= 99) return GlucoseStatus.normal;
      if (value <= 125) return GlucoseStatus.elevated;
      return GlucoseStatus.high;
    }
    // post-meal / random
    if (value < 140) return GlucoseStatus.normal;
    if (value < 200) return GlucoseStatus.elevated;
    return GlucoseStatus.high;
  }
}

enum GlucoseStatus { low, normal, elevated, high }
