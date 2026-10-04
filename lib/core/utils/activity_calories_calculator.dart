import 'package:flutter/material.dart';

/// Preset physical activity definitions with evidence-based MET values
/// from the Compendium of Physical Activities, discounted with a conservative
/// factor (pessimistic estimate) to ensure caloric deficits are preserved.
enum PhysicalActivityType {
  swimming(
    displayName: 'Swimming (Pool Laps / Workout)',
    icon: Icons.pool,
    pessimisticMet: 5.0,
    isSwimming: true,
  ),
  weightlifting(
    displayName: 'Weightlifting / Gym Resistance',
    icon: Icons.fitness_center,
    pessimisticMet: 3.5,
  ),
  running(
    displayName: 'Running / Jogging (~8 km/h)',
    icon: Icons.directions_run,
    pessimisticMet: 7.0,
  ),
  walking(
    displayName: 'Brisk Walking / Incline Treadmill',
    icon: Icons.directions_walk,
    pessimisticMet: 3.0,
  ),
  cycling(
    displayName: 'Cycling / Stationary Bike',
    icon: Icons.directions_bike,
    pessimisticMet: 5.5,
  ),
  hiit(
    displayName: 'HIIT / Circuit Training',
    icon: Icons.bolt,
    pessimisticMet: 6.5,
  ),
  football(
    displayName: 'Football / Soccer',
    icon: Icons.sports_soccer,
    pessimisticMet: 6.0,
  ),
  basketball(
    displayName: 'Basketball',
    icon: Icons.sports_basketball,
    pessimisticMet: 5.5,
  ),
  tennis(
    displayName: 'Tennis / Padel',
    icon: Icons.sports_tennis,
    pessimisticMet: 5.0,
  ),
  rowing(
    displayName: 'Rowing Machine',
    icon: Icons.rowing,
    pessimisticMet: 5.0,
  ),
  jumpRope(
    displayName: 'Jump Rope',
    icon: Icons.airline_stops,
    pessimisticMet: 7.5,
  ),
  boxing(
    displayName: 'Boxing / Kickboxing',
    icon: Icons.sports_mma,
    pessimisticMet: 6.0,
  ),
  hiking(
    displayName: 'Hiking / Trail Walk',
    icon: Icons.terrain,
    pessimisticMet: 4.5,
  ),
  yoga(
    displayName: 'Yoga / Pilates / Mobility',
    icon: Icons.self_improvement,
    pessimisticMet: 2.0,
  ),
  crossfit(
    displayName: 'CrossFit / Functional Fitness',
    icon: Icons.whatshot,
    pessimisticMet: 6.0,
  );

  const PhysicalActivityType({
    required this.displayName,
    required this.icon,
    required this.pessimisticMet,
    this.isSwimming = false,
  });

  final String displayName;
  final IconData icon;
  final double pessimisticMet;
  final bool isSwimming;

  /// Calculates conservative active calories burned:
  /// round(0.85 * MET * WeightKg * (DurationMinutes / 60))
  int calculateBurn({
    required double weightKg,
    required int durationMinutes,
  }) {
    if (weightKg <= 0 || durationMinutes <= 0) return 0;
    const double safetyMultiplier = 0.85;
    final double burned = safetyMultiplier * pessimisticMet * weightKg * (durationMinutes / 60.0);
    return burned.round();
  }
}

/// Represents a single logged activity instance in the daily logger
class LoggedActivity {
  LoggedActivity({
    required this.id,
    required this.activityType,
    this.durationMinutes = 45,
    this.customCalories,
    this.isDurationMode = true,
  });

  final String id;
  PhysicalActivityType activityType;
  int durationMinutes;
  int? customCalories;
  bool isDurationMode;

  /// Returns the effective calories for this activity
  int getCalories(double currentWeightKg) {
    if (!isDurationMode && customCalories != null && customCalories! > 0) {
      return customCalories!;
    }
    return activityType.calculateBurn(
      weightKg: currentWeightKg,
      durationMinutes: durationMinutes,
    );
  }
}
