import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../viewmodel/history_viewmodel.dart';
import '../widgets/quick_summary_card.dart';
import '../widgets/trend_chart_card.dart';
import '../widgets/entry_card.dart';
import 'healing_progress_screen.dart';
import '../../../data/repositories/wounds_repository.dart';
import '../../shell/controllers/shell_controller.dart';

class WoundHistoryScreen extends StatefulWidget {
  const WoundHistoryScreen({super.key});

  @override
  State<WoundHistoryScreen> createState() => _WoundHistoryScreenState();
}

class _WoundHistoryScreenState extends State<WoundHistoryScreen> {
  int _lastTabIndex = -1;

  @override
  Widget build(BuildContext context) {
    // Listen to ShellController to detect tab changes
    return Consumer<ShellController>(
      builder: (context, shell, _) {
        return ChangeNotifierProvider(
          create: (_) => HistoryViewModel(),
          child: Consumer<HistoryViewModel>(
            builder: (context, vm, _) {
              // Refresh when history tab (index 1) becomes active
              final shouldRefresh = shell.index == 1 && _lastTabIndex != 1;
              if (shouldRefresh) {
                _lastTabIndex = shell.index;
                // Schedule refresh after current build
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    vm.refresh();
                  }
                });
              } else if (shell.index != 1) {
                _lastTabIndex = shell.index;
              }

              final t = Theme.of(context);
              return Scaffold(
            appBar: AppBar(
              title: Text("wound_photo_history".tr(), style: TextStyle(fontSize: 18.sp)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => vm.refresh(),
                  tooltip: 'refresh'.tr(),
                ),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: () => vm.refresh(),
              child: ListView(
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
                    HistoryEntryCard(entry: e, onView: () async {
                      // Load full analysis result from database
                      final repo = WoundsRepository();
                      final analysisResult = await repo.getAnalysisResultById(e.id ?? 0);
                      
                      final detail = HealingResult(
                        length: e.lengthCm,
                        width: e.widthCm,
                        depth: e.depthCm ?? (analysisResult?.depth ?? 0.0),
                        tissueType: analysisResult?.tissueType ?? 'Granulation',
                        pusLevel: analysisResult?.pusLevel ?? 'Moderate',
                        inflammation: e.inflammation,
                        weeklyProgress: e.progressPct,
                        graphImagePath: 'assets/images/progress_graph.png',
                      );

                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HealingProgressScreen(entry: e, result: detail),
                          ),
                        );
                      }
                    },),
                  ],
                )),
                SizedBox(height: 24.h),
              ],
              ),
            ),
          );
          },
        ),
      );
      },
    );
  }

// Date formatter using localized month abbreviations
  String _fmtDate(DateTime d) {
    final monthKey = d.month.toString();
    final monthName = 'months_abbr.$monthKey'.tr();
    return "${d.day} $monthName ${d.year}";
  }
}
