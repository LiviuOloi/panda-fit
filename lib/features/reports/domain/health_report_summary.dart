import '../../../core/utils/calculation_engine.dart';
import '../../daily_logger/domain/daily_entry_model.dart';
import '../../missions/domain/mission_model.dart';
import '../../profile/domain/profile_model.dart';

class HealthReportSummary {
  final UserProfile profile;
  final Mission? activeMission;
  final List<DailyEntry> entries;
  final DateTime generatedAt;

  final int totalEntriesLogged;
  final double startWeight;
  final double currentWeight;
  final double lowestWeight;
  final double highestWeight;
  final double totalDelta;
  final double currentMovingAvg;
  final double? weeklyChangeRate;
  final int streakDays;
  final double dietAdherencePercent;
  final int avgCaloriesIn;
  final int avgCaloriesOut;
  final int avgNetCalories;
  final double bmi;
  final int bmr;
  final int maintenanceTdee;
  final MissionEtaEstimate? missionEta;

  HealthReportSummary._({
    required this.profile,
    required this.activeMission,
    required this.entries,
    required this.generatedAt,
    required this.totalEntriesLogged,
    required this.startWeight,
    required this.currentWeight,
    required this.lowestWeight,
    required this.highestWeight,
    required this.totalDelta,
    required this.currentMovingAvg,
    required this.weeklyChangeRate,
    required this.streakDays,
    required this.dietAdherencePercent,
    required this.avgCaloriesIn,
    required this.avgCaloriesOut,
    required this.avgNetCalories,
    required this.bmi,
    required this.bmr,
    required this.maintenanceTdee,
    required this.missionEta,
  });

  factory HealthReportSummary.fromData({
    required UserProfile profile,
    required List<DailyEntry> entries,
    Mission? activeMission,
  }) {
    final startWeight = profile.profileStartWeight;
    final latest = entries.isNotEmpty ? entries.first : null;
    final currentWeight = latest?.weight ?? startWeight;
    final movingAvg = latest?.rollingAvg7Days ?? currentWeight;

    final totalDelta = CalculationEngine.calculateTotalDelta(
      currentWeight: currentWeight,
      profileStartWeight: startWeight,
    );

    double lowest = startWeight;
    double highest = startWeight;
    if (entries.isNotEmpty) {
      final validWeights = entries.map((e) => e.weight).whereType<double>().toList();
      if (validWeights.isNotEmpty) {
        lowest = validWeights.reduce((a, b) => a < b ? a : b);
        highest = validWeights.reduce((a, b) => a > b ? a : b);
      }
    }

    // Chronological weights and dates for weekly rate
    final chronoWeights = entries.reversed
        .map((e) => e.rollingAvg7Days ?? e.weight)
        .whereType<double>()
        .toList();
    final chronoDates = entries.reversed
        .where((e) => (e.rollingAvg7Days ?? e.weight) != null)
        .map((e) => e.entryDate)
        .toList();

    final weeklyRate = CalculationEngine.calculateWeeklyRate(
      weights: chronoWeights,
      dates: chronoDates,
    );

    // Consecutive streak
    final loggedDates = entries.map((e) => e.entryDate).toList();
    final streak = CalculationEngine.calculateStreak(loggedDates);

    // Diet adherence
    final planFollowedDays = entries.map((e) => e.planFollowed).toList();
    final adherenceInt = CalculationEngine.calculateDietAdherence(planFollowedDays);

    // Calories averages
    final entriesWithCalIn = entries.where((e) => e.caloriesIn != null && e.caloriesIn! > 0).toList();
    final avgIn = entriesWithCalIn.isNotEmpty
        ? (entriesWithCalIn.fold<int>(0, (s, e) => s + e.caloriesIn!) / entriesWithCalIn.length).round()
        : profile.dailyTargetCalories;

    final entriesWithCalOut = entries.where((e) => e.caloriesOut != null && e.caloriesOut! > 0).toList();
    final avgOut = entriesWithCalOut.isNotEmpty
        ? (entriesWithCalOut.fold<int>(0, (s, e) => s + e.caloriesOut!) / entriesWithCalOut.length).round()
        : 0;

    final avgNet = avgIn - avgOut;

    // BMI calculation
    final heightM = profile.heightCm / 100.0;
    final bmi = heightM > 0
        ? (((currentWeight / (heightM * heightM)) * 10).round() / 10.0)
        : 0.0;

    // Metabolic engines
    final bmr = CalculationEngine.calculateBMR(
      weightKg: currentWeight,
      heightCm: profile.heightCm,
      age: profile.age,
      sex: profile.sex,
    );

    final maintenance = CalculationEngine.calculateMaintenanceCalories(
      weightKg: currentWeight,
      heightCm: profile.heightCm,
      age: profile.age,
      sex: profile.sex,
    );

    // Mission ETA
    MissionEtaEstimate? eta;
    if (activeMission != null) {
      eta = CalculationEngine.calculateMissionETA(
        missionType: activeMission.missionType.name,
        currentWeight: currentWeight,
        targetWeight: activeMission.targetWeight,
        observedWeeklyPace: weeklyRate,
      );
    }

    return HealthReportSummary._(
      profile: profile,
      activeMission: activeMission,
      entries: entries,
      generatedAt: DateTime.now(),
      totalEntriesLogged: entries.length,
      startWeight: startWeight,
      currentWeight: currentWeight,
      lowestWeight: lowest,
      highestWeight: highest,
      totalDelta: totalDelta,
      currentMovingAvg: movingAvg,
      weeklyChangeRate: weeklyRate,
      streakDays: streak,
      dietAdherencePercent: adherenceInt.toDouble(),
      avgCaloriesIn: avgIn,
      avgCaloriesOut: avgOut,
      avgNetCalories: avgNet,
      bmi: bmi,
      bmr: bmr,
      maintenanceTdee: maintenance,
      missionEta: eta,
    );
  }
}
