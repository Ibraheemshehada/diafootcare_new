/// A completed **System Usability Scale** (SUS) response.
///
/// SUS (Brooke, 1986 — © Digital Equipment Corporation) is a 10-item
/// questionnaire answered on a 1–5 Likert scale (1 = strongly disagree,
/// 5 = strongly agree). Items alternate polarity: odd-numbered items are
/// positively worded, even-numbered items are negatively worded.
///
/// Scoring (standard):
///   * odd items (Q1,3,5,7,9): contribution = response − 1
///   * even items (Q2,4,6,8,10): contribution = 5 − response
///   * SUS score = sum(contributions) × 2.5  →  0..100
///
/// Note: the SUS score is **not** a percentage; 68 is the conventional
/// average benchmark.
class SusEntry {
  final String id;
  final DateTime dateTime;

  /// Raw item responses Q1..Q10, each 1..5, in order.
  final List<int> responses;

  SusEntry({
    required this.id,
    required this.dateTime,
    required this.responses,
  }) : assert(responses.length == susItemCount);

  /// Sum of the 10 item contributions (0..40).
  int get rawSum {
    var sum = 0;
    for (var i = 0; i < susItemCount; i++) {
      final v = responses[i];
      // index 0 == Q1 (odd, positive), index 1 == Q2 (even, negative), ...
      sum += susItemIsPositive(i) ? (v - 1) : (5 - v);
    }
    return sum;
  }

  /// Official SUS score, 0..100 (68 = average benchmark).
  double get score => rawSum * 2.5;

  Map<String, dynamic> toMap() => {
        'id': id,
        'dateTime': dateTime.millisecondsSinceEpoch,
        for (var i = 0; i < susItemCount; i++) 'q${i + 1}': responses[i],
      };

  factory SusEntry.fromMap(Map<String, dynamic> m) => SusEntry(
        id: m['id'] as String,
        dateTime:
            DateTime.fromMillisecondsSinceEpoch((m['dateTime'] as int?) ?? 0),
        responses: List<int>.generate(
            susItemCount, (i) => (m['q${i + 1}'] as int?) ?? 3),
      );
}

const int susItemCount = 10;

/// Odd-numbered SUS items (Q1, Q3, …) are positively worded.
/// [index] is 0-based, so index 0 == Q1.
bool susItemIsPositive(int index) => index % 2 == 0;

/// Localization key for a SUS statement: `sus_q1` … `sus_q10`.
String susItemKey(int index) => 'sus_q${index + 1}';

/// Localization key for the qualitative band of a SUS [score] (0..100).
/// Benchmarks follow the common Bangor/Sauro adjective bands.
String susAdjectiveKey(double score) {
  if (score >= 85) return 'sus_band_excellent';
  if (score >= 68) return 'sus_band_good'; // 68 = average benchmark
  if (score >= 51) return 'sus_band_ok';
  return 'sus_band_poor';
}
