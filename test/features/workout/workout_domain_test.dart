import 'package:flutter_test/flutter_test.dart';
import 'package:panda_fit/features/workout/domain/exercise_library.dart';
import 'package:panda_fit/features/workout/domain/exercise_model.dart';
import 'package:panda_fit/features/workout/presentation/workout_controller.dart';

void main() {
  group('Workout Domain & Logger Tests', () {
    test('ExerciseSet computes volume correctly based on completion state', () {
      final set1 = ExerciseSet(setNumber: 1, weightKg: 80.0, reps: 10, isCompleted: true);
      final set2 = ExerciseSet(setNumber: 2, weightKg: 85.0, reps: 8, isCompleted: false);

      // Volume = weight * reps when completed
      expect(set1.volume, 800.0);
      // Volume = 0 when not completed
      expect(set2.volume, 0.0);

      final completedSet2 = set2.copyWith(isCompleted: true);
      expect(completedSet2.volume, 680.0);
    });

    test('ExerciseSet JSON serialization and deserialization', () {
      final original = ExerciseSet(
        setNumber: 3,
        weightKg: 100.5,
        reps: 6,
        isCompleted: true,
        rpe: 8.5,
      );

      final json = original.toJson();
      final restored = ExerciseSet.fromJson(json);

      expect(restored.setNumber, 3);
      expect(restored.weightKg, 100.5);
      expect(restored.reps, 6);
      expect(restored.isCompleted, isTrue);
      expect(restored.rpe, 8.5);
    });

    test('WorkoutExercise calculates total volume and completed sets count', () {
      final benchPress = ExerciseLibrary.findById('chest_bench_press')!;
      final exercise = WorkoutExercise(
        exerciseInfo: benchPress,
        sets: [
          ExerciseSet(setNumber: 1, weightKg: 60.0, reps: 12, isCompleted: true),
          ExerciseSet(setNumber: 2, weightKg: 80.0, reps: 10, isCompleted: true),
          ExerciseSet(setNumber: 3, weightKg: 90.0, reps: 6, isCompleted: false),
        ],
      );

      expect(exercise.completedSetsCount, 2);
      // 60*12 + 80*10 = 720 + 800 = 1520 kg
      expect(exercise.totalVolume, 1520.0);
    });

    test('WorkoutSession aggregates total volume, reps, and sets across exercises', () {
      final bench = ExerciseLibrary.findById('chest_bench_press')!;
      final squat = ExerciseLibrary.findById('legs_squat')!;

      final session = WorkoutSession(
        id: 'session-123',
        name: 'Full Body Test',
        split: WorkoutSplit.fullBody,
        startTime: DateTime(2026, 10, 20, 10, 0),
        endTime: DateTime(2026, 10, 20, 10, 50),
        durationMinutes: 50,
        exercises: [
          WorkoutExercise(
            exerciseInfo: bench,
            sets: [
              ExerciseSet(setNumber: 1, weightKg: 70.0, reps: 10, isCompleted: true),
              ExerciseSet(setNumber: 2, weightKg: 70.0, reps: 10, isCompleted: true),
            ],
          ),
          WorkoutExercise(
            exerciseInfo: squat,
            sets: [
              ExerciseSet(setNumber: 1, weightKg: 100.0, reps: 8, isCompleted: true),
              ExerciseSet(setNumber: 2, weightKg: 100.0, reps: 8, isCompleted: true),
            ],
          ),
        ],
        caloriesBurned: 280,
      );

      // Bench: 70*10 + 70*10 = 1400 kg. Squat: 100*8 + 100*8 = 1600 kg. Total = 3000 kg.
      expect(session.totalVolumeKg, 3000.0);
      expect(session.totalCompletedSets, 4);
      // Reps: 10 + 10 + 8 + 8 = 36 reps
      expect(session.totalReps, 36);

      // JSON roundtrip
      final json = session.toJson();
      final restored = WorkoutSession.fromJson(json);
      expect(restored.name, 'Full Body Test');
      expect(restored.split, WorkoutSplit.fullBody);
      expect(restored.totalVolumeKg, 3000.0);
      expect(restored.caloriesBurned, 280);
    });

    test('ExerciseLibrary contains 30+ exercises and covers all muscle groups', () {
      expect(ExerciseLibrary.allExercises.length, greaterThanOrEqualTo(30));

      final groupsInLibrary =
          ExerciseLibrary.allExercises.map((e) => e.muscleGroup).toSet();
      // Verifies each MuscleGroup has exercises
      for (final group in MuscleGroup.values) {
        expect(
          groupsInLibrary.contains(group),
          isTrue,
          reason: 'Muscle group ${group.name} should have exercises in library',
        );
      }

      final found = ExerciseLibrary.findById('legs_squat');
      expect(found, isNotNull);
      expect(found!.nameRo, 'Genuflexiuni cu Bara pe Spate');
      expect(found.muscleGroup, MuscleGroup.legs);
    });

    test('WorkoutTemplate builds initial exercises with 3 sets each', () {
      expect(ExerciseLibrary.presetTemplates, isNotEmpty);
      final push = ExerciseLibrary.presetTemplates
          .firstWhere((t) => t.split == WorkoutSplit.push);

      final initialExercises = push.buildInitialExercises();
      expect(initialExercises.length, push.exerciseIds.length);
      for (final ex in initialExercises) {
        expect(ex.sets.length, 3);
        expect(ex.sets.first.weightKg, 20.0);
        expect(ex.sets.first.reps, 10);
      }
    });

    test('RestTimerState computes fractional progress accurately', () {
      const state1 = RestTimerState(isActive: true, totalSeconds: 90, remainingSeconds: 45);
      expect(state1.progress, 0.5);

      const state2 = RestTimerState(isActive: true, totalSeconds: 120, remainingSeconds: 120);
      expect(state2.progress, 1.0);

      const state3 = RestTimerState(isActive: false, totalSeconds: 60, remainingSeconds: 0);
      expect(state3.progress, 0.0);
    });
  });
}
