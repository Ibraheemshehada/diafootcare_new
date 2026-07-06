/// A medication the patient should take [timesPerDay] times each day.
class Medication {
  final String id;
  final String name;
  final String dosage; // free text, e.g. "500 mg"
  final int timesPerDay; // 1..4
  final DateTime createdAt;

  Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.timesPerDay,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'dosage': dosage,
        'timesPerDay': timesPerDay,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Medication.fromMap(Map<String, dynamic> m) => Medication(
        id: m['id'] as String,
        name: m['name'] as String,
        dosage: (m['dosage'] as String?) ?? '',
        timesPerDay: (m['timesPerDay'] as int?) ?? 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (m['createdAt'] as int?) ?? 0),
      );

  /// Stable key for one dose slot on one day: "medId|yyyymmdd|doseIndex".
  static String doseKey(String medicationId, String dateKey, int doseIndex) =>
      '$medicationId|$dateKey|$doseIndex';
}

/// yyyymmdd key for a date (local).
String medDateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
