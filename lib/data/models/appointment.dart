/// A scheduled clinic appointment. A local notification can be fired ahead of
/// [dateTime] by [reminderLead] minutes (-1 = no reminder).
class Appointment {
  final String id;
  final String title;
  final DateTime dateTime;
  final String location;
  final String notes;
  final int reminderLead; // minutes before dateTime; -1 = no reminder
  final DateTime createdAt;

  Appointment({
    required this.id,
    required this.title,
    required this.dateTime,
    this.location = '',
    this.notes = '',
    required this.reminderLead,
    required this.createdAt,
  });

  bool get isPast => dateTime.isBefore(DateTime.now());

  /// When the reminder should fire, or null when reminders are off.
  DateTime? get remindAt => reminderLead < 0
      ? null
      : dateTime.subtract(Duration(minutes: reminderLead));

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'dateTime': dateTime.millisecondsSinceEpoch,
        'location': location,
        'notes': notes,
        'reminderLead': reminderLead,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Appointment.fromMap(Map<String, dynamic> m) => Appointment(
        id: m['id'] as String,
        title: (m['title'] as String?) ?? '',
        dateTime:
            DateTime.fromMillisecondsSinceEpoch((m['dateTime'] as int?) ?? 0),
        location: (m['location'] as String?) ?? '',
        notes: (m['notes'] as String?) ?? '',
        reminderLead: (m['reminderLead'] as int?) ?? -1,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch((m['createdAt'] as int?) ?? 0),
      );
}

/// Reminder lead-time options (minutes before the appointment).
/// -1 = none, 0 = at time, 60 = 1 hour before, 1440 = 1 day before.
const List<int> appointmentLeadOptions = <int>[-1, 0, 60, 1440];

/// Localization key for a lead-time option.
String appointmentLeadKey(int minutes) {
  switch (minutes) {
    case -1:
      return 'appt_lead_none';
    case 0:
      return 'appt_lead_attime';
    case 60:
      return 'appt_lead_1h';
    case 1440:
      return 'appt_lead_1d';
    default:
      return 'appt_lead_none';
  }
}
