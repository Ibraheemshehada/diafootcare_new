import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../viewmodel/history_viewmodel.dart';
import '../widgets/quick_summary_card.dart';
import '../widgets/trend_chart_card.dart';
import '../widgets/entry_card.dart';
import 'healing_progress_screen.dart';

class WoundHistoryScreen extends StatelessWidget {
  const WoundHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HistoryViewModel(),
      child: Consumer<HistoryViewModel>(
        builder: (context, vm, _) {
          final t = Theme.of(context);
          return Scaffold(
            appBar: AppBar(title: Text("wound_photo_history".tr(), style: TextStyle(fontSize: 18.sp))),
            body: ListView(
              children: [
                SizedBox(height: 8.h),
                QuickSummaryCard(
                  totalEntries: vm.totalEntries,
                  improvementPct: vm.overallImprovementPct,
                  inflammationTrend: vm.inflammationTrend,
                ),
                TrendChartCard(monthlyTrend: vm.monthlyTrend),
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 6.h),
                  child: Text("recent".tr(), style: t.textTheme.titleMedium),
                ),
                ...vm.entries.map((e) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
                      child: Text(
                        _fmtDate(e.date),
                        style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    HistoryEntryCard(entry: e, onView: () {
                      final detail = HealingResult(
                        length: e.lengthCm,
                        width: e.widthCm,
                        depth: 3.2,               // TODO: replace with real value
                        tissueType: 'Granulation'.tr(),// TODO from analysis
                        pusLevel: 'Moderate'.tr(),
                        inflammation: e.inflammation,
                        weeklyProgress: e.progressPct,
                        graphImagePath: 'assets/images/progress_graph.png',
                      );

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HealingProgressScreen(entry: e, result: detail),
                        ),
                      );
                    },),
                  ],
                )),
                SizedBox(height: 24.h),
              ],
            ),
          );
        },
      ),
    );
  }

// Date formatter using localized month abbreviations
  String _fmtDate(DateTime d) {
    final monthKey = d.month.toString();
    final monthName = 'months_abbr.$monthKey'.tr();
    return "${d.day} $monthName ${d.year}";
  }
}
