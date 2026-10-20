import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/calculation_engine.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/panda_button.dart';
import '../../daily_logger/domain/daily_entry_model.dart';
import '../../missions/domain/mission_model.dart';
import '../../profile/presentation/profile_controller.dart';
import '../../reports/presentation/export_report_dialog.dart';
import '../widgets/metric_summary_card.dart';
import '../widgets/weight_progress_chart.dart';

enum DashboardTimeRange {
  days7('7Z', 7),
  days30('30Z', 30),
  days90('90Z', 90),
  all('TOT', null);

  final String label;
  final int? days;

  const DashboardTimeRange(this.label, this.days);
}

class DashboardScreen extends ConsumerStatefulWidget {
  final VoidCallback onQuickLogPressed;

  const DashboardScreen({
    super.key,
    required this.onQuickLogPressed,
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DashboardTimeRange _selectedTimeRange = DashboardTimeRange.days30;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final missionAsync = ref.watch(activeMissionProvider);
    final entriesAsync = ref.watch(dailyEntriesProvider);

    final profile = profileAsync.value;
    final activeMission = missionAsync.value;
    final entries = entriesAsync.value ?? [];

    final startWeight = profile?.profileStartWeight ?? 100.0;
    final latestEntry = entries.isNotEmpty ? entries.first : null;
    final currentWeight = latestEntry?.weight ?? startWeight;
    final movingAvg = latestEntry?.rollingAvg7Days ?? currentWeight;
    final totalDelta = CalculationEngine.calculateTotalDelta(
      currentWeight: currentWeight,
      profileStartWeight: startWeight,
    );

    final targetWeight = activeMission?.targetWeight ?? (startWeight - 5.0);
    final missionProgress = activeMission != null ? activeMission.progress(currentWeight) : 0.0;

    final latestCaloriesIn = latestEntry?.caloriesIn ?? profile?.dailyTargetCalories ?? 2300;
    final latestCaloriesOut = latestEntry?.caloriesOut ?? 0;
    final netCalories = CalculationEngine.calculateNetCalories(
      caloriesIn: latestCaloriesIn,
      caloriesOut: latestCaloriesOut,
    );

    final isCutting = activeMission?.missionType == MissionType.cutting;

    // Filter entries by selected timeframe
    final List<DailyEntry> filteredEntries;
    if (_selectedTimeRange.days != null && entries.isNotEmpty) {
      final now = DateTime.now();
      final cutoffDate = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: _selectedTimeRange.days! - 1));
      final matching = entries.where((e) => !e.entryDate.isBefore(cutoffDate)).toList();
      filteredEntries = matching.isNotEmpty ? matching : entries.take(_selectedTimeRange.days!).toList();
    } else {
      filteredEntries = entries;
    }

    // Build chart data points from chronological filtered entries
    final List<WeightChartDataPoint> chartPoints;
    if (filteredEntries.isNotEmpty) {
      chartPoints = filteredEntries.reversed.map((e) {
        return WeightChartDataPoint(
          date: e.entryDate,
          rawWeight: e.weight,
          movingAvg7Days: e.rollingAvg7Days,
        );
      }).toList();
    } else if (entries.isNotEmpty) {
      chartPoints = entries.reversed.map((e) {
        return WeightChartDataPoint(
          date: e.entryDate,
          rawWeight: e.weight,
          movingAvg7Days: e.rollingAvg7Days,
        );
      }).toList();
    } else {
      chartPoints = [
        WeightChartDataPoint(
          date: DateTime.now(),
          rawWeight: startWeight,
          movingAvg7Days: startWeight,
        ),
      ];
    }

    // Analytical Insights Calculations
    final allDates = entries.map((e) => e.entryDate).toList();
    final streakDays = CalculationEngine.calculateStreak(allDates);
    final adherenceList = filteredEntries.map((e) => e.planFollowed).toList();
    final adherencePercent = CalculationEngine.calculateDietAdherence(adherenceList);

    // Weekly rate from chronological points in the timeframe (or all)
    final rateEntries = filteredEntries.length >= 2 ? filteredEntries : entries;
    final chronoWeights = rateEntries.reversed
        .map((e) => e.rollingAvg7Days ?? e.weight)
        .whereType<double>()
        .toList();
    final chronoDates = rateEntries.reversed
        .where((e) => (e.rollingAvg7Days ?? e.weight) != null)
        .map((e) => e.entryDate)
        .toList();
    final weeklyRate = CalculationEngine.calculateWeeklyRate(
      weights: chronoWeights,
      dates: chronoDates,
    );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 420;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.emerald,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    profile != null
                                        ? 'PANDAFIT · ${profile.firstName.toUpperCase()}'
                                        : 'PANDAFIT ENGINE',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.1,
                                      color: AppColors.emerald,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Metabolic Overview',
                              style: TextStyle(
                                fontSize: isCompact ? 21 : 26,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Rapoarte & Export Date (PDF, CSV, JSON)',
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.surfaceElevated,
                              side: const BorderSide(color: AppColors.glassBorder),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.all(8),
                              minimumSize: const Size(38, 38),
                            ),
                            icon: const Icon(Icons.file_download_outlined, color: AppColors.cyan, size: 19),
                            onPressed: () {
                              if (profile == null) return;
                              ExportReportDialog.show(
                                context,
                                profile: profile,
                                entries: entries,
                                activeMission: activeMission,
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          PandaButton(
                            label: isCompact ? 'Log' : 'Quick Log',
                            icon: Icons.add,
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            fontSize: 13,
                            onPressed: widget.onQuickLogPressed,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // Active Mission Progress Banner
              GlassCard(
                borderColor: AppColors.emerald.withValues(alpha: 0.35),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.emerald.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'ACTIVE MISSION',
                                  style: TextStyle(
                                    color: AppColors.emeraldLight,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              Text(
                                isCutting ? 'Cutting Phase (Fat Loss)' : 'Bulking Phase (Muscle Gain)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(missionProgress * 100).clamp(0, 100).toInt()}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.emerald,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(6)),
                      child: LinearProgressIndicator(
                        value: missionProgress.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: AppColors.surfaceElevated,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emerald),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text('Start: $startWeight kg', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        Text(
                          'Strict Target: ${isCutting ? "<" : ">"} $targetWeight kg',
                          style: const TextStyle(color: AppColors.emeraldLight, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Metric Summary Cards Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 600;
                  final isVeryNarrow = constraints.maxWidth < 360;
                  return GridView.count(
                    crossAxisCount: isWide ? 4 : 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: isWide ? 1.4 : (isVeryNarrow ? 1.05 : 1.15),
                    children: [
                      MetricSummaryCard(
                        title: 'Morning Weight',
                        value: '$currentWeight kg',
                        delta: entries.isNotEmpty ? '${totalDelta >= 0 ? "+" : ""}$totalDelta kg' : 'Baseline',
                        subtitle: entries.isNotEmpty ? 'latest entry' : 'start baseline',
                        icon: Icons.scale,
                        accentColor: AppColors.cyan,
                      ),
                      MetricSummaryCard(
                        title: '7-Day Rolling MA',
                        value: '$movingAvg kg',
                        delta: '${(movingAvg - startWeight).toStringAsFixed(1)} kg',
                        subtitle: 'true fat trend',
                        icon: Icons.trending_down,
                        accentColor: AppColors.emerald,
                      ),
                      MetricSummaryCard(
                        title: 'Total Delta',
                        value: '${totalDelta >= 0 ? "+" : ""}$totalDelta kg',
                        subtitle: 'from start ($startWeight kg)',
                        icon: Icons.flag,
                        accentColor: AppColors.amber,
                        delta: '$totalDelta kg',
                      ),
                      MetricSummaryCard(
                        title: 'Net Calories',
                        value: '$netCalories kcal',
                        subtitle: '$latestCaloriesIn in · $latestCaloriesOut out',
                        icon: Icons.local_fire_department,
                        accentColor: AppColors.rose,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // Analytics & Consistency Insights Cards
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // 1. Weekly Rate
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.speed_rounded, size: 14, color: AppColors.cyanLight),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Viteză Trend',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            weeklyRate != null
                                ? '${weeklyRate >= 0 ? "+" : ""}$weeklyRate kg/săpt'
                                : (entries.length < 2 ? 'După 2+ zile' : 'Stabil'),
                            style: TextStyle(
                              color: weeklyRate != null
                                  ? (weeklyRate < 0 ? AppColors.emeraldLight : AppColors.cyanLight)
                                  : AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            weeklyRate != null && weeklyRate.abs() <= 1.0
                                ? 'Pace sustenabil'
                                : (weeklyRate != null ? 'Pace accelerat' : 'Tendință netă'),
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 42, color: AppColors.glassBorder),
                    const SizedBox(width: 10),

                    // 2. Logging Streak
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.local_fire_department_rounded, size: 14, color: AppColors.amber),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Streak Activ',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            streakDays > 0 ? '$streakDays ${streakDays == 1 ? "zi" : "zile"}' : '0 zile',
                            style: const TextStyle(
                              color: AppColors.amber,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Loghează zilnic',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 42, color: AppColors.glassBorder),
                    const SizedBox(width: 10),

                    // 3. Diet Adherence
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.verified_rounded, size: 14, color: AppColors.emeraldLight),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Aderență Plan',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$adherencePercent%',
                            style: TextStyle(
                              color: adherencePercent >= 80 ? AppColors.emeraldLight : AppColors.amber,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            adherencePercent >= 85 ? 'Respectat' : 'Deviații',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 7-Day Moving Average vs Raw Chart with Time Range Filter
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Weight Trend & Rolling MA',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Media 7Z filtrează apa & retenția de sodiu',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Timeframe Pill Selector
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: DashboardTimeRange.values.map((range) {
                              final isSelected = _selectedTimeRange == range;
                              return InkWell(
                                onTap: () => setState(() => _selectedTimeRange = range),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.emerald.withValues(alpha: 0.25)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: isSelected
                                        ? Border.all(color: AppColors.emerald.withValues(alpha: 0.5))
                                        : null,
                                  ),
                                  child: Text(
                                    range.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? AppColors.emeraldLight : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Legend Row
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _buildLegendItem('Cântar Zilnic', AppColors.cyan),
                        _buildLegendItem('Medie 7Z (Trend Real)', AppColors.emerald),
                        if (activeMission != null)
                          _buildLegendItem('Țintă Misiune', AppColors.amber),
                      ],
                    ),
                    const SizedBox(height: 20),

                    WeightProgressChart(
                      points: chartPoints,
                      targetWeight: targetWeight,
                      startWeight: startWeight,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
