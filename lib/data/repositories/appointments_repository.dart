import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/services/notification_service.dart';
import '../local/database_helper.dart';
import '../models/appointment.dart';

class AppointmentsRepository {
  final _helper = DatabaseHelper();
  final _notifs = NotificationService.I;

  Future<List<Appointment>> getAll() async {
    final Database db = await _helper.database;
    final rows = await db.query('appointments', orderBy: 'dateTime ASC');
    return rows.map((e) => Appointment.fromMap(e)).toList();
  }

  Future<void> insert(Appointment a) async {
    final db = await _helper.database;
    await db.insert('appointments', a.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    final db = await _helper.database;
    await db.delete('appointments', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> _notificationsEnabled() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool('notifications_enabled') ?? true;
  }

  /// Notification body: formatted date/time (+ location when present).
  String _body(Appointment a) {
    final when = intl.DateFormat('EEE, MMM d • h:mm a').format(a.dateTime);
    final loc = a.location.trim();
    return loc.isEmpty ? when : '$when · $loc';
  }

  /// Schedule (or replace) the one-off reminder for [a]. Per-appointment id, so
  /// it never touches the reminders feature's notifications.
  Future<void> scheduleReminder(Appointment a) async {
    await _notifs.init();
    if (!await _notificationsEnabled()) return;
    final remindAt = a.remindAt;
    if (remindAt == null || remindAt.isBefore(DateTime.now())) return;
    await _notifs.scheduleOneOff(
      id: _notifs.notifIdFromKey(a.id),
      title: a.title,
      body: _body(a),
      whenLocal: remindAt,
    );
  }

  Future<void> cancelReminder(Appointment a) async {
    await _notifs.init();
    await _notifs.cancel(_notifs.notifIdFromKey(a.id));
  }
}
