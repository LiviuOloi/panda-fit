import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/panda_button.dart';
import '../widgets/metric_summary_card.dart';
import '../widgets/weight_progress_chart.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback onQuickLogPressed;

  const DashboardScreen({
    super.key,
    required this.onQuickLogPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Demo / Sample active metrics
    const currentWeight = 98.4;
    const movingAvg = 98.9;
    const startWeight = 104.2;
    const totalDelta = -5.8;
    const targetWeight = 94.0;
    const missionProgress = 0.56;

    final chartPoints = [
      WeightChartDataPoint(date: DateTime.now().subtract(const Duration(days: 6)), rawWeight: 99.8, movingAvg7Days: 100.1),
      WeightChartDataPoint(date: DateTime.now().subtract(const Duration(days: 5)), rawWeight: 99.2, movingAvg7Days: 99.8),
      WeightChartDataPoint(date: DateTime.now().subtract(const Duration(days: 4)), rawWeight: 99.5, movingAvg7Days: 99.6),
      WeightChartDataPoint(date: DateTime.now().subtract(const Duration(days: 3)), rawWeight: 98.9, movingAvg7Days: 99.3),
      WeightChartDataPoint(date: DateTime.now().subtract(const Duration(days: 2)), rawWeight: 98.7, movingAvg7Days: 99.1),
      WeightChartDataPoint(date: DateTime.now().subtract(const Duration(days: 1)), rawWeight: 98.6, movingAvg7Days: 99.0),
      WeightChartDataPoint(date: DateTime.now(), rawWeight: 98.4, movingAvg7Days: 98.9),
    ];

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
                          const Text(
                            'PANDAFIT ENGINE',
                            style: TextStyle(
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
                            const Text(
                              'Cut Phase 1',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${(missionProgress * 100).toInt()}%',
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
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: missionProgress,
                        minHeight: 8,
                        backgroundColor: AppColors.surfaceElevated,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emerald),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Start: 104.2 kg', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        Text('Strict Target: < 94.0 kg', style: TextStyle(color: AppColors.emeraldLight, fontSize: 12, fontWeight: FontWeight.w600)),
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
                      const MetricSummaryCard(
                        title: 'Morning Weight',
                        value: '$currentWeight kg',
                        delta: '-0.2 kg',
                        subtitle: 'vs yesterday',
                        icon: Icons.scale,
                        accentColor: AppColors.cyan,
                      ),
                      const MetricSummaryCard(
                        title: '7-Day Rolling MA',
                        value: '$movingAvg kg',
                        delta: '-0.7 kg/wk',
                        subtitle: 'true fat trend',
                        icon: Icons.trending_down,
                        accentColor: AppColors.emerald,
                      ),
                      MetricSummaryCard(
                        title: 'Total Delta',
                        value: '${totalDelta >= 0 ? "+" : ""}$totalDelta kg',
                        subtitle: 'from start (104.2k)',
                        icon: Icons.flag,
                        accentColor: AppColors.amber,
                        delta: '$totalDelta kg',
                      ),
                      const MetricSummaryCard(
                        title: 'Net Calories',
                        value: '1,850 kcal',
                        subtitle: '2,300 in · 450 out',
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
