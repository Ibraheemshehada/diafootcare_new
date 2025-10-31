import 'package:flutter/material.dart';
import '../../../data/models/note.dart';
import '../../../data/models/service_item.dart';

class HomeViewModel extends ChangeNotifier {
  String userFirstName = "Ahmed";
  TimeOfDay nextReminder = const TimeOfDay(hour: 15, minute: 0);
  int weeklyProgressPercent = 12;

  final List<Note> recentNotes = [
    Note(
      date: DateTime(2025, 7, 24),
      text: "The wound looks slightly smaller today. No signs of redness. Pain level lower than yesterday.",
      id: "1"
    ),
    Note(
      date: DateTime(2025, 7, 23),
      text: "Mild redness around the edges. Applied ointment after cleaning. Pain when touching.",
      id: "2"
    ),
  ];

  final services = [
    ServiceItem(
      title: "Capture Wound",
      subtitle: "Capture your wound clearly to track healing.",
      iconAsset: "assets/svg/scan.svg",
      bgSvgAsset: "assets/svg/bg_capture.svg",
      route: "/capture",
      isPrimary: true,
      bgScale: 1.1,            // a hair larger than the tile
      bgAlignment: Alignment.centerRight,
      bgOffsetX: 0.02,         // nudge a bit to the right
      bgOffsetY: 0.00,
      bgOpacity: 0.20,         // a bit stronger for the blue gradient
    ),

    ServiceItem(
      title: "Log Measurements",
      subtitle: "Record size and depth changes over time.",
      iconAsset: "assets/svg/Log_Measurements.svg",
      bgSvgAsset: "assets/svg/bg_measurements.svg",
      route: "/WoundHistoryScreen",
      isPrimary: false,
      bgScale: 0.75,           // slightly larger than tile
      bgAlignment: Alignment.topRight,
      bgOffsetX: 0.10,         // push further right so pills peek in
      bgOffsetY: 0.06,         // push down a bit
      bgOpacity: 0.07,
    ),

    ServiceItem(
      title: "Daily Reminders",
      subtitle: "Stay on track with helpful care alerts.",
      iconAsset: "assets/svg/clock.svg",
      bgSvgAsset: "assets/svg/bg_reminders.svg",
      route: "/reminders",
      isPrimary: false,
      bgScale: 0.60,           // big diagonal shape
      bgAlignment: Alignment.centerRight,
      bgOffsetX: 0.00,
      bgOffsetY: 0.00,
      bgOpacity: 0.06,
    ),

    ServiceItem(
      title: "Daily Notes",
      subtitle: "Keep helpful care notes.",
      iconAsset: "assets/svg/note.svg",
      bgSvgAsset: "assets/svg/bg_notes.svg",
      route: "/notes",
      isPrimary: false,
      bgScale: 0.75,
      bgAlignment: Alignment.centerRight,
      bgOffsetX: 0.04,
      bgOffsetY: 0.00,
      bgOpacity: 0.07,
    ),
  ];

// TODO: Later – read name from Firebase user + next reminder from SQLite.
}
