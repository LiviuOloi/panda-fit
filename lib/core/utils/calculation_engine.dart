import 'dart:math' as math;

/// Core Mathematical and Domain Invariant Calculation Engine for PandaFit
class CalculationEngine {
  CalculationEngine._();

  /// Rounds any weight value to exactly 1 decimal place (0.1 kg precision)
  static double roundWeight(double weight) {
    return (weight * 10).roundToDouble() / 10.0;
  }

  /// Calculates user age accurately based on birth date and reference date
  static int calculateAge(DateTime birthDate, [DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  /// Calculates the 7-day rolling moving average for a target date
  /// [entries] is a list of pairs (Date, Weight).
  /// Considers entries in the 7-calendar-day window [targetDate - 6 days, targetDate].
  static double? calculate7DayMovingAverage({
    required DateTime targetDate,
    required Map<DateTime, double> dailyWeights,
  }) {
    final normalizedTarget = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final windowStart = normalizedTarget.subtract(const Duration(days: 6));

    double sum = 0.0;
    int count = 0;

    dailyWeights.forEach((date, weight) {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      if (!normalizedDate.isBefore(windowStart) && !normalizedDate.isAfter(normalizedTarget)) {
        sum += weight;
        count++;
      }
    });

    if (count == 0) return null;
    return roundWeight(sum / count);
  }

  /// Calculates total delta from profile starting weight
  /// Negative means weight loss, Positive means weight gain
  static double calculateTotalDelta({
    required double currentWeight,
    required double profileStartWeight,
  }) {
    return roundWeight(currentWeight - profileStartWeight);
  }

  /// Calculates Net Calories: Calories In - Calories Out
  static int calculateNetCalories({
    required int caloriesIn,
    int caloriesOut = 0,
  }) {
    return caloriesIn - caloriesOut;
  }

  /// Checks if a mission is accomplished strictly according to domain invariants:
  /// - CUTTING: currentWeight < targetWeight (strict inequality)
  /// - BULKING: currentWeight > targetWeight (strict inequality)
  static bool isMissionAccomplished({
    required String missionType, // 'CUTTING' or 'BULKING'
    required double currentWeight,
    required double targetWeight,
  }) {
    final roundedCurrent = roundWeight(currentWeight);
    final roundedTarget = roundWeight(targetWeight);

    if (missionType == 'CUTTING') {
      return roundedCurrent < roundedTarget;
    } else if (missionType == 'BULKING') {
      return roundedCurrent > roundedTarget;
    }
    return false;
  }

  /// Calculates progress percentage towards mission target (0.0 to 1.0+)
  static double calculateMissionProgress({
    required String missionType,
    required double startWeight,
    required double targetWeight,
    required double currentWeight,
  }) {
    final totalSpan = (targetWeight - startWeight).abs();
    if (totalSpan < 0.001) return 0.0;

    if (missionType == 'CUTTING') {
      final lost = startWeight - currentWeight;
      return math.max(0.0, lost / totalSpan);
    } else if (missionType == 'BULKING') {
      final gained = currentWeight - startWeight;
      return math.max(0.0, gained / totalSpan);
    }
    return 0.0;
  }
}
