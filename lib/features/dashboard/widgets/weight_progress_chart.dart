import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart_rounded, size: 36, color: AppColors.textMuted),
            SizedBox(height: 8),
            Text(
              'Nu există date în intervalul selectat.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final validWeights = points.map((p) => p.rawWeight).whereType<double>().toList();
    final validAvgs = points.map((p) => p.movingAvg7Days).whereType<double>().toList();
    final allValues = [...validWeights, ...validAvgs];

    if (allValues.isEmpty) {
      return Container(
        height: 240,
        alignment: Alignment.center,
        child: const Text(
          'Nu există valori valide de greutate înregistrate.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    double minY = allValues.reduce((a, b) => a < b ? a : b) - 1.5;
    double maxY = allValues.reduce((a, b) => a > b ? a : b) + 1.5;

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

    // Adaptive bottom title interval
    double bottomInterval = 1.0;
    if (points.length > 45) {
      bottomInterval = (points.length / 5).floorToDouble();
    } else if (points.length > 15) {
      bottomInterval = (points.length / 5).floorToDouble();
    } else if (points.length > 7) {
      bottomInterval = 2.0;
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
            horizontalInterval: (maxY - minY > 10) ? 4.0 : 2.0,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: AppColors.surfaceElevated.withValues(alpha: 0.35),
                strokeWidth: 1,
              );
            },
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (targetWeight != null)
                HorizontalLine(
                  y: targetWeight!,
                  color: AppColors.amber.withValues(alpha: 0.7),
                  strokeWidth: 1.5,
                  dashArray: [6, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    padding: const EdgeInsets.only(right: 6, bottom: 2),
                    style: const TextStyle(
                      color: AppColors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    labelResolver: (_) => 'Țintă: ${targetWeight!.toStringAsFixed(1)} kg',
                  ),
                ),
            ],
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: (maxY - minY > 10) ? 4.0 : 2.0,
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
                interval: bottomInterval,
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
            // Daily Raw Weights (Cyan dashed / translucent dots and line)
            if (rawSpots.isNotEmpty)
              LineChartBarData(
                spots: rawSpots,
                isCurved: true,
                curveSmoothness: 0.2,
                color: AppColors.cyan.withValues(alpha: 0.65),
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: points.length <= 35,
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
                      AppColors.emerald.withValues(alpha: 0.22),
                      AppColors.emerald.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
          ],
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.surface,
              tooltipRoundedRadius: 10,
              tooltipBorder: const BorderSide(color: AppColors.glassBorder, width: 1),
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              getTooltipItems: (touchedSpots) {
                if (touchedSpots.isEmpty) return [];
                final idx = touchedSpots.first.x.toInt();
                final p = (idx >= 0 && idx < points.length) ? points[idx] : null;
                final dateLabel = p != null ? DateFormat('d MMM yyyy').format(p.date) : '';

                return touchedSpots.map((spot) {
                  final isMA = spot.barIndex == (rawSpots.isNotEmpty ? 1 : 0);
                  final isFirst = spot == touchedSpots.first;

                  final header = isFirst ? '$dateLabel\n' : '';
                  final label = isMA ? 'Medie 7Z: ' : 'Cântar: ';
                  final deltaStr = (targetWeight != null && isFirst)
                      ? '\nΔ Țintă: ${(spot.y - targetWeight!).toStringAsFixed(1)} kg'
                      : '';

                  return LineTooltipItem(
                    '$header$label${spot.y.toStringAsFixed(1)} kg$deltaStr',
                    TextStyle(
                      color: isMA ? AppColors.emeraldLight : AppColors.cyanLight,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      height: 1.3,
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
