import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class WeightChartDataPoint {
  final DateTime date;
  final double? rawWeight;
  final double? movingAvg7Days;

  const WeightChartDataPoint({
    required this.date,
    this.rawWeight,
    this.movingAvg7Days,
  });
}

class WeightProgressChart extends StatelessWidget {
  final List<WeightChartDataPoint> points;
  final double? targetWeight;
  final double? startWeight;

  const WeightProgressChart({
    super.key,
    required this.points,
    this.targetWeight,
    this.startWeight,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Container(
        height: 240,
        alignment: Alignment.center,
        child: const Text(
          'No weigh-in data logged yet. Add your morning weight to visualize trends.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    final validWeights = points.map((p) => p.rawWeight).whereType<double>().toList();
    final validAvgs = points.map((p) => p.movingAvg7Days).whereType<double>().toList();

    double minY = (validWeights + validAvgs).reduce((a, b) => a < b ? a : b) - 2.0;
    double maxY = (validWeights + validAvgs).reduce((a, b) => a > b ? a : b) + 2.0;

    if (targetWeight != null) {
      if (targetWeight! < minY) minY = targetWeight! - 1.0;
      if (targetWeight! > maxY) maxY = targetWeight! + 1.0;
    }

    final rawSpots = <FlSpot>[];
    final maSpots = <FlSpot>[];

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      if (p.rawWeight != null) {
        rawSpots.add(FlSpot(i.toDouble(), p.rawWeight!));
      }
      if (p.movingAvg7Days != null) {
        maSpots.add(FlSpot(i.toDouble(), p.movingAvg7Days!));
      }
    }

    return AspectRatio(
      aspectRatio: 1.7,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 2,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: AppColors.surfaceElevated.withValues(alpha: 0.4),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: 2,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toStringAsFixed(0)}k',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: (points.length / 5).clamp(1.0, 30.0),
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < points.length) {
                    final d = points[idx].date;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '${d.day}/${d.month}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            // Daily Raw Weights (Cyan dashed / translucent line)
            if (rawSpots.isNotEmpty)
              LineChartBarData(
                spots: rawSpots,
                isCurved: true,
                curveSmoothness: 0.2,
                color: AppColors.cyan.withValues(alpha: 0.6),
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 3.5,
                      color: AppColors.cyan,
                      strokeWidth: 1,
                      strokeColor: AppColors.background,
                    );
                  },
                ),
              ),
            // 7-Day Moving Average (Emerald Solid Bold line with gradient fill)
            if (maSpots.isNotEmpty)
              LineChartBarData(
                spots: maSpots,
                isCurved: true,
                curveSmoothness: 0.35,
                color: AppColors.emerald,
                barWidth: 3.5,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.emerald.withValues(alpha: 0.25),
                      AppColors.emerald.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.surfaceElevated,
              tooltipRoundedRadius: 8,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final isMA = spot.barIndex == (rawSpots.isNotEmpty ? 1 : 0);
                  return LineTooltipItem(
                    '${isMA ? "7d MA: " : "Raw: "}${spot.y.toStringAsFixed(1)} kg',
                    TextStyle(
                      color: isMA ? AppColors.emerald : AppColors.cyan,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}
