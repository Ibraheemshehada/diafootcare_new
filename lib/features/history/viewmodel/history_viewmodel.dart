import 'package:flutter/foundation.dart';
import '../../../data/models/wound_entry.dart';

class HistoryViewModel extends ChangeNotifier {
  // Quick summary
  final int totalEntries = 12;
  final int overallImprovementPct = 31;
  final String inflammationTrend = "Decreasing";

  // Trend data (fake for now)
  final List<double> monthlyTrend = [12,14,13,16,18,15,15]; // Feb..Aug

  // Recent entries
  final List<WoundEntry> entries =  [
    WoundEntry(
        date:  DateTime(2025,7,24),
        imagePath: 'assets/images/forget_password.png',
        lengthCm: 8.1, widthCm: 5.3, inflammation: 'None', progressPct: 12),
    WoundEntry(
        date:  DateTime(2025,7,10),
        imagePath: 'assets/images/forget_password.png',
        lengthCm: 8.1, widthCm: 5.3, inflammation: 'None', progressPct: 12),
    WoundEntry(
        date:  DateTime(2025,7,10),
        imagePath: 'assets/images/forget_password.png',
        lengthCm: 8.1, widthCm: 5.3, inflammation: 'None', progressPct: 12),
  ];
}
