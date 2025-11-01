import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../data/models/note.dart';
import '../../../data/models/service_item.dart';
import '../../../data/repositories/reminders_repo.dart';
import '../../../data/repositories/wounds_repository.dart';
import '../../../data/models/reminder.dart';

class HomeViewModel extends ChangeNotifier {
  String userFirstName = "";
  TimeOfDay? nextReminder;
  String? nextReminderTitle; // Title of the next reminder
  int weeklyProgressPercent = 0;

  HomeViewModel() {
    _loadUserData();
    _loadNextReminder();
    _calculateWeeklyProgress();
  }

  // Load user first name from SharedPreferences
  Future<void> _loadUserData() async {
    await refreshUserData();
  }
  
  // Public method to refresh user data (can be called after signup/login)
  Future<void> refreshUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userFirstName = prefs.getString('user_firstName') ?? '';

      // If no local data, try to get from Firebase
      if (userFirstName.isEmpty) {
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          final displayName = firebaseUser.displayName;
          if (displayName != null && displayName.isNotEmpty) {
            userFirstName = displayName.split(' ').first;
            
            // Save back to SharedPreferences if we got it from Firebase
            final parts = displayName.split(' ');
            final firstName = parts.first;
            final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
            await prefs.setString('user_firstName', firstName);
            await prefs.setString('user_lastName', lastName);
            await prefs.setString('user_email', firebaseUser.email ?? '');
            await prefs.setString('user_fullName', displayName);
          }
        }
      }

      // Fallback if still empty
      if (userFirstName.isEmpty) {
        userFirstName = 'User'; // Default fallback
      }

      notifyListeners();
      debugPrint('🏠 Home: User first name loaded: $userFirstName');
    } catch (e) {
      debugPrint('❌ Error loading user data for home: $e');
      userFirstName = 'User'; // Fallback
      notifyListeners();
    }
  }

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

  /// Load the next upcoming reminder
  Future<void> _loadNextReminder() async {
    try {
      final remindersRepo = RemindersRepo();
      final reminders = await remindersRepo.load();
      
      // Filter enabled reminders
      final enabledReminders = reminders.where((r) => r.enabled).toList();
      if (enabledReminders.isEmpty) {
        nextReminder = null;
        nextReminderTitle = null;
        notifyListeners();
        return;
      }

      final now = DateTime.now();
      TimeOfDay? earliestNext;
      Reminder? nextReminderObj;

      for (var reminder in enabledReminders) {
        DateTime? nextOccurrence;

        if (reminder.isOneOff()) {
          // One-off reminder: check if it's today or in the future
          final reminderDate = reminder.oneOffDate!;
          final reminderDateTime = DateTime(
            reminderDate.year,
            reminderDate.month,
            reminderDate.day,
            reminder.time.hour,
            reminder.time.minute,
          );

          if (reminderDateTime.isAfter(now)) {
            nextOccurrence = reminderDateTime;
          } else if (reminderDateTime.year == now.year &&
                     reminderDateTime.month == now.month &&
                     reminderDateTime.day == now.day &&
                     reminderDateTime.hour * 60 + reminderDateTime.minute >= now.hour * 60 + now.minute) {
            nextOccurrence = reminderDateTime;
          }
        } else if (reminder.repeatsDaily()) {
          // Daily reminder: today if time hasn't passed, otherwise tomorrow
          final todayAtTime = DateTime(now.year, now.month, now.day, reminder.time.hour, reminder.time.minute);
          if (todayAtTime.isAfter(now)) {
            nextOccurrence = todayAtTime;
          } else {
            nextOccurrence = todayAtTime.add(const Duration(days: 1));
          }
        } else {
          // Weekly reminder: find next occurrence
          final todayWeekday = now.weekday; // 1=Monday, 7=Sunday
          if (reminder.weekdays.contains(todayWeekday)) {
            final todayAtTime = DateTime(now.year, now.month, now.day, reminder.time.hour, reminder.time.minute);
            if (todayAtTime.isAfter(now)) {
              nextOccurrence = todayAtTime;
            } else {
              // Find next weekday occurrence
              for (var i = 1; i <= 7; i++) {
                final checkDate = now.add(Duration(days: i));
                final checkWeekday = checkDate.weekday;
                if (reminder.weekdays.contains(checkWeekday)) {
                  nextOccurrence = DateTime(checkDate.year, checkDate.month, checkDate.day, reminder.time.hour, reminder.time.minute);
                  break;
                }
              }
            }
          } else {
            // Find next weekday occurrence
            for (var i = 1; i <= 7; i++) {
              final checkDate = now.add(Duration(days: i));
              final checkWeekday = checkDate.weekday;
              if (reminder.weekdays.contains(checkWeekday)) {
                nextOccurrence = DateTime(checkDate.year, checkDate.month, checkDate.day, reminder.time.hour, reminder.time.minute);
                break;
              }
            }
          }
        }

        // Compare with current earliest
        if (nextOccurrence != null) {
          DateTime? currentEarliest;
          if (nextReminderObj != null) {
            if (nextReminderObj.isOneOff()) {
              currentEarliest = DateTime(
                nextReminderObj.oneOffDate!.year,
                nextReminderObj.oneOffDate!.month,
                nextReminderObj.oneOffDate!.day,
                nextReminderObj.time.hour,
                nextReminderObj.time.minute,
              );
            } else {
              // For daily/weekly, find next occurrence
              final todayAtTime = DateTime(now.year, now.month, now.day, nextReminderObj.time.hour, nextReminderObj.time.minute);
              if (todayAtTime.isAfter(now)) {
                currentEarliest = todayAtTime;
              } else {
                currentEarliest = todayAtTime.add(const Duration(days: 1));
              }
            }
          }
          
          if (currentEarliest == null || nextOccurrence.isBefore(currentEarliest)) {
            nextReminderObj = reminder;
            earliestNext = reminder.time;
          }
        }
      }

      nextReminder = earliestNext;
      nextReminderTitle = nextReminderObj?.title;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading next reminder: $e');
      nextReminder = null;
      nextReminderTitle = null;
      notifyListeners();
    }
  }

  /// Calculate weekly progress from wound entries
  Future<void> _calculateWeeklyProgress() async {
    try {
      final woundsRepo = WoundsRepository();
      final wounds = await woundsRepo.loadAllWoundsForExport();
      
      if (wounds.isEmpty) {
        weeklyProgressPercent = 0;
        notifyListeners();
        return;
      }

      // Sort by date (oldest first)
      wounds.sort((a, b) {
        final dateA = DateTime.parse(a['date'] as String);
        final dateB = DateTime.parse(b['date'] as String);
        return dateA.compareTo(dateB);
      });

      final now = DateTime.now();

      // Find entry from approximately one week ago (at least 7 days old, closest to 7 days)
      Map<String, dynamic>? weekAgoEntry;
      for (var wound in wounds.reversed) {
        final woundDate = DateTime.parse(wound['date'] as String);
        final daysDiff = now.difference(woundDate).inDays;
        if (daysDiff >= 7) {
          weekAgoEntry = wound;
          break;
        }
      }

      // If no entry from exactly one week ago, use oldest entry if we have at least 2 entries
      if (weekAgoEntry == null && wounds.length >= 2) {
        weekAgoEntry = wounds.first;
      }

      // Get most recent entry
      final mostRecentEntry = wounds.isNotEmpty ? wounds.last : null;

      if (weekAgoEntry != null && mostRecentEntry != null) {
        final weekAgoLength = (weekAgoEntry['length'] as num?)?.toDouble() ?? 0.0;
        final weekAgoWidth = (weekAgoEntry['width'] as num?)?.toDouble() ?? 0.0;
        final weekAgoArea = weekAgoLength * weekAgoWidth;

        final recentLength = (mostRecentEntry['length'] as num?)?.toDouble() ?? 0.0;
        final recentWidth = (mostRecentEntry['width'] as num?)?.toDouble() ?? 0.0;
        final recentArea = recentLength * recentWidth;

        if (weekAgoArea > 0) {
          // Positive means improvement (area decreased), negative means deterioration (area increased)
          final change = ((weekAgoArea - recentArea) / weekAgoArea * 100).round();
          weeklyProgressPercent = change.clamp(-100, 100);
        } else {
          weeklyProgressPercent = 0;
        }
      } else {
        weeklyProgressPercent = 0;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error calculating weekly progress: $e');
      weeklyProgressPercent = 0;
      notifyListeners();
    }
  }

  /// Refresh all home data (call when returning to home screen)
  Future<void> refresh() async {
    await Future.wait([
      refreshUserData(),
      _loadNextReminder(),
      _calculateWeeklyProgress(),
    ]);
  }
}
