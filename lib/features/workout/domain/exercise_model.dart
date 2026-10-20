import 'package:flutter/material.dart';

/// Target Muscle Groups for Strength & Resistance Training
enum MuscleGroup {
  chest(displayName: 'Piept', englishName: 'Chest', icon: Icons.fitness_center),
  back(displayName: 'Spate', englishName: 'Back', icon: Icons.sports_gymnastics),
  legs(displayName: 'Picioare', englishName: 'Legs', icon: Icons.directions_walk),
  shoulders(displayName: 'Umeri', englishName: 'Shoulders', icon: Icons.accessibility_new),
  arms(displayName: 'Brațe', englishName: 'Arms', icon: Icons.sports_martial_arts),
  core(displayName: 'Abdomen / Core', englishName: 'Core', icon: Icons.crop_square),
  fullBody(displayName: 'Tot Corpul', englishName: 'Full Body', icon: Icons.sports),
  cardio(displayName: 'Cardio & Anduranță', englishName: 'Cardio', icon: Icons.favorite);

  final String displayName;
  final String englishName;
  final IconData icon;

  const MuscleGroup({
    required this.displayName,
    required this.englishName,
    required this.icon,
  });
}

/// Static definition of an exercise in the library
class ExerciseInfo {
  final String id;
  final String nameRo;
  final String nameEn;
  final MuscleGroup muscleGroup;
  final String equipment; // Bara, Gantere, Cablu, Aparat, Greutate Corporala

  const ExerciseInfo({
    required this.id,
    required this.nameRo,
    required this.nameEn,
    required this.muscleGroup,
    required this.equipment,
  });

  String get displayName => '$nameRo ($nameEn)';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name_ro': nameRo,
        'name_en': nameEn,
        'muscle_group': muscleGroup.name,
        'equipment': equipment,
      };

  factory ExerciseInfo.fromJson(Map<String, dynamic> json) {
    return ExerciseInfo(
      id: json['id'] as String,
      nameRo: json['name_ro'] as String,
      nameEn: json['name_en'] as String,
      muscleGroup: MuscleGroup.values.firstWhere(
        (m) => m.name == json['muscle_group'],
        orElse: () => MuscleGroup.fullBody,
      ),
      equipment: json['equipment'] as String? ?? 'Echipament',
    );
  }
}

/// A logged set inside an exercise
class ExerciseSet {
  int setNumber;
  double weightKg;
  int reps;
  bool isCompleted;
  double? rpe; // 6.0 to 10.0

  ExerciseSet({
    required this.setNumber,
    required this.weightKg,
    required this.reps,
    this.isCompleted = false,
    this.rpe,
  });

  /// Volume Load (kg) = weight * reps
  double get volume => isCompleted ? (weightKg * reps) : 0.0;

  Map<String, dynamic> toJson() => {
        'set_number': setNumber,
        'weight_kg': weightKg,
        'reps': reps,
        'is_completed': isCompleted,
        'rpe': rpe,
      };

  factory ExerciseSet.fromJson(Map<String, dynamic> json) {
    return ExerciseSet(
      setNumber: json['set_number'] as int? ?? 1,
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0.0,
      reps: json['reps'] as int? ?? 0,
      isCompleted: json['is_completed'] as bool? ?? false,
      rpe: (json['rpe'] as num?)?.toDouble(),
    );
  }

  ExerciseSet copyWith({
    int? setNumber,
    double? weightKg,
    int? reps,
    bool? isCompleted,
    double? rpe,
  }) {
    return ExerciseSet(
      setNumber: setNumber ?? this.setNumber,
      weightKg: weightKg ?? this.weightKg,
      reps: reps ?? this.reps,
      isCompleted: isCompleted ?? this.isCompleted,
      rpe: rpe ?? this.rpe,
    );
  }
}

/// An exercise with its list of performed sets inside a workout session
class WorkoutExercise {
  final ExerciseInfo exerciseInfo;
  final List<ExerciseSet> sets;

  WorkoutExercise({
    required this.exerciseInfo,
    required this.sets,
  });

  double get totalVolume => sets.fold(0.0, (acc, s) => acc + s.volume);

  int get completedSetsCount => sets.where((s) => s.isCompleted).length;

  Map<String, dynamic> toJson() => {
        'exercise_info': exerciseInfo.toJson(),
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    return WorkoutExercise(
      exerciseInfo: ExerciseInfo.fromJson(json['exercise_info'] as Map<String, dynamic>),
      sets: (json['sets'] as List<dynamic>?)
              ?.map((s) => ExerciseSet.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Workout Training Split Type
enum WorkoutSplit {
  push(displayName: 'Push (Piept, Umeri, Triceps)'),
  pull(displayName: 'Pull (Spate, Biceps)'),
  legs(displayName: 'Legs (Picioare & Gambe)'),
  upper(displayName: 'Upper Body (Partea Superioară)'),
  lower(displayName: 'Lower Body (Partea Inferioară)'),
  fullBody(displayName: 'Full Body (Tot Corpul)'),
  cardio(displayName: 'Cardio & Anduranță'),
  custom(displayName: 'Antrenament Personalizat');

  final String displayName;
  const WorkoutSplit({required this.displayName});
}

/// Completed or In-Progress Workout Session
class WorkoutSession {
  final String id;
  final String name;
  final WorkoutSplit split;
  final DateTime startTime;
  DateTime? endTime;
  final int durationMinutes;
  final List<WorkoutExercise> exercises;
  final String? notes;
  final int caloriesBurned;

  WorkoutSession({
    required this.id,
    required this.name,
    required this.split,
    required this.startTime,
    this.endTime,
    required this.durationMinutes,
    required this.exercises,
    this.notes,
    required this.caloriesBurned,
  });

  double get totalVolumeKg => exercises.fold(0.0, (acc, e) => acc + e.totalVolume);

  int get totalCompletedSets => exercises.fold(0, (acc, e) => acc + e.completedSetsCount);

  int get totalReps => exercises.fold(
        0,
        (acc, e) => acc + e.sets.where((s) => s.isCompleted).fold(0, (sAcc, s) => sAcc + s.reps),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'split': split.name,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'duration_minutes': durationMinutes,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'notes': notes,
        'calories_burned': caloriesBurned,
        'total_volume_kg': totalVolumeKg,
      };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    return WorkoutSession(
      id: json['id'] as String,
      name: json['name'] as String,
      split: WorkoutSplit.values.firstWhere(
        (s) => s.name == json['split'],
        orElse: () => WorkoutSplit.custom,
      ),
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time'] as String) : null,
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      exercises: (json['exercises'] as List<dynamic>?)
              ?.map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      notes: json['notes'] as String?,
      caloriesBurned: json['calories_burned'] as int? ?? 0,
    );
  }
}
