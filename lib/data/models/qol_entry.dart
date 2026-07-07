/// A periodic quality-of-life check-in. All three items are 0–10 where a
/// *higher* score means a *worse* burden (more pain / more difficulty / more
/// distress), so they can be averaged into a single burden score for trends.
class QolEntry {
  final String id;
  final DateTime dateTime;
  final int pain; // 0..10
  final int mobility; // 0..10 (difficulty walking / moving)
  final int emotional; // 0..10 (worry / low mood)

  QolEntry({
    required this.id,
    required this.dateTime,
    required this.pain,
    required this.mobility,
    required this.emotional,
  });

  /// Average burden 0..10 (higher = worse).
  double get burden => (pain + mobility + emotional) / 3.0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'dateTime': dateTime.millisecondsSinceEpoch,
        'pain': pain,
        'mobility': mobility,
        'emotional': emotional,
      };

  factory QolEntry.fromMap(Map<String, dynamic> m) => QolEntry(
        id: m['id'] as String,
        dateTime:
            DateTime.fromMillisecondsSinceEpoch((m['dateTime'] as int?) ?? 0),
        pain: (m['pain'] as int?) ?? 0,
        mobility: (m['mobility'] as int?) ?? 0,
        emotional: (m['emotional'] as int?) ?? 0,
      );
}

/// A satisfaction-survey response. Each item is a 1–5 Likert where a *higher*
/// score means *more agreement* (better).
class SatisfactionEntry {
  final String id;
  final DateTime dateTime;
  final int ease; // 1..5 easy to use
  final int usefulness; // 1..5 helpful for care
  final int willingness; // 1..5 would keep using

  SatisfactionEntry({
    required this.id,
    required this.dateTime,
    required this.ease,
    required this.usefulness,
    required this.willingness,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'dateTime': dateTime.millisecondsSinceEpoch,
        'ease': ease,
        'usefulness': usefulness,
        'willingness': willingness,
      };

  factory SatisfactionEntry.fromMap(Map<String, dynamic> m) => SatisfactionEntry(
        id: m['id'] as String,
        dateTime:
            DateTime.fromMillisecondsSinceEpoch((m['dateTime'] as int?) ?? 0),
        ease: (m['ease'] as int?) ?? 3,
        usefulness: (m['usefulness'] as int?) ?? 3,
        willingness: (m['willingness'] as int?) ?? 3,
      );
}
