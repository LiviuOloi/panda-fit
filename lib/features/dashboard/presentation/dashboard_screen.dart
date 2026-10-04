import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/calculation_engine.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/panda_button.dart';
import '../../missions/domain/mission_model.dart';
import '../../profile/presentation/profile_controller.dart';
import '../widgets/metric_summary_card.dart';
import '../widgets/weight_progress_chart.dart';

class DashboardScreen extends ConsumerWidget {
  final VoidCallback onQuickLogPressed;

  const DashboardScreen({
    super.key,
    required this.onQuickLogPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    // Build chart data points from real chronological history
    final List<WeightChartDataPoint> chartPoints;
    if (entries.isNotEmpty) {
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

    final isCutting = activeMission?.missionType == MissionType.cutting;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.emerald,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            profile != null ? 'PANDAFIT · ${profile.firstName.toUpperCase()}' : 'PANDAFIT ENGINE',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: AppColors.emerald,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Metabolic Overview',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  PandaButton(
                    label: 'Quick Log',
                    icon: Icons.add,
                    onPressed: onQuickLogPressed,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Active Mission Progress Banner
              GlassCard(
                borderColor: AppColors.emerald.withValues(alpha: 0.35),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                            const SizedBox(width: 8),
                            Text(
                              isCutting ? 'Cutting Phase (Fat Loss)' : 'Bulking Phase (Muscle Gain)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  return GridView.count(
                    crossAxisCount: isWide ? 4 : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: isWide ? 1.4 : 1.15,
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
              const SizedBox(height: 24),

              // 7-Day Moving Average vs Raw Chart
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Weight Trend & Rolling MA (7D)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Eliminates water noise and glycogen spikes',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            _buildLegendItem('Raw', AppColors.cyan),
                            const SizedBox(width: 12),
                            _buildLegendItem('7d MA', AppColors.emerald),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
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
