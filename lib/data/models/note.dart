class Note {
  final String id;
  final DateTime date; // local date (no time zone math here)
  final String text;

  Note({required this.id, required this.date, required this.text});

  // DB helpers
  Map<String, dynamic> toMap() => {
    'id': id,
    'date': DateTime(date.year, date.month, date.day)
        .millisecondsSinceEpoch, // store as int
    'text': text,
  };

  factory Note.fromMap(Map<String, dynamic> m) => Note(
    id: m['id'] as String,
    date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
    text: m['text'] as String,
  );
}