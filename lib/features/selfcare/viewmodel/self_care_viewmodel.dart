import 'dart:math';

import 'package:flutter/material.dart';

import '../../../data/models/self_care_task.dart';
import '../../../data/repositories/self_care_repository.dart';

class SelfCareViewModel extends ChangeNotifier {
  final SelfCareRepository _repo = SelfCareRepository();
  final Random _rng = Random();

  /// How many days back we load to compute the completion streak.
  static const int _streakWindow = 60;

  final List<String> tasks = selfCareTaskKeys;
  Set<String> _doneToday = {};
  Map<String, int> _recentCounts = {}; // dateKey -> completed count
  bool _isLoading = false;

  /// A single foot-care tip, chosen at random once per app launch (and again
  /// whenever the user taps the shuffle button). Kept stable across [load]
  /// refreshes so returning to the screen doesn't reshuffle it.
  SelfCareTip? _tip;
  SelfCareTip? get tip => _tip;

  bool get isLoading => _isLoading;
  int get totalTasks => tasks.length;
  int get doneToday => _doneToday.length;

  String get _todayKey => selfCareDateKey(DateTime.now());

  /// Today's completion 0..100.
  int get adherenceTodayPct {
    if (totalTasks == 0) return 0;
    return ((doneToday / totalTasks) * 100).round().clamp(0, 100);
  }

  bool isDone(String itemKey) => _doneToday.contains(itemKey);

  /// Consecutive fully-completed days ending today. A not-yet-finished today
  /// does not break the streak (it just isn't counted until finished).
  int get streak {
    if (totalTasks == 0) return 0;
    final now = DateTime.now();
    int s = 0;
    for (int i = 0; i < _streakWindow; i++) {
      final dayKey = selfCareDateKey(now.subtract(Duration(days: i)));
      final count = dayKey == _todayKey ? doneToday : (_recentCounts[dayKey] ?? 0);
      final complete = count >= totalTasks;
      if (complete) {
        s++;
      } else if (i == 0) {
        // Today isn't finished yet — keep the streak from yesterday alive.
        continue;
      } else {
        break;
      }
    }
    return s;
  }

  SelfCareViewModel() {
    if (selfCareTips.isNotEmpty) {
      _tip = selfCareTips[_rng.nextInt(selfCareTips.length)];
    }
    load();
  }

  /// Pick a different random tip (never repeats the current one).
  void shuffleTip() {
    if (selfCareTips.length < 2) return;
    SelfCareTip next;
    do {
      next = selfCareTips[_rng.nextInt(selfCareTips.length)];
    } while (identical(next, _tip));
    _tip = next;
    notifyListeners();
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _doneToday = await _repo.doneItemsForDate(_todayKey);
      final now = DateTime.now();
      final keys = List.generate(
          _streakWindow, (i) => selfCareDateKey(now.subtract(Duration(days: i))));
      _recentCounts = await _repo.completedCountByDate(keys);
    } catch (e) {
      debugPrint('❌ Error loading self-care log: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggle(String itemKey) async {
    final currentlyDone = _doneToday.contains(itemKey);
    if (currentlyDone) {
      _doneToday.remove(itemKey);
    } else {
      _doneToday.add(itemKey);
    }
    // Keep today's entry in the recent-counts map in sync so the streak updates.
    _recentCounts[_todayKey] = _doneToday.length;
    notifyListeners();
    try {
      await _repo.setDone(
        itemKey: itemKey,
        dateKey: _todayKey,
        done: !currentlyDone,
      );
    } catch (e) {
      debugPrint('❌ Error toggling self-care task: $e');
    }
  }
}
