import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/activity_calories_calculator.dart';
import '../../profile/presentation/profile_controller.dart';
import '../data/workout_repository.dart';
import '../domain/exercise_model.dart';

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository();
});

/// List of saved workout sessions
final workoutSessionsProvider =
    AsyncNotifierProvider<WorkoutSessionsNotifier, List<WorkoutSession>>(
  WorkoutSessionsNotifier.new,
);

class WorkoutSessionsNotifier extends AsyncNotifier<List<WorkoutSession>> {
  @override
  Future<List<WorkoutSession>> build() async {
    final repo = ref.watch(workoutRepositoryProvider);
    return repo.loadWorkoutSessions();
  }

  Future<void> saveSession(WorkoutSession session) async {
    final repo = ref.read(workoutRepositoryProvider);
    await repo.saveWorkoutSession(session);
    ref.invalidateSelf();
  }

  Future<void> deleteSession(String sessionId) async {
    final repo = ref.read(workoutRepositoryProvider);
    await repo.deleteWorkoutSession(sessionId);
    ref.invalidateSelf();
  }
}

/// Rest Timer State
class RestTimerState {
  final bool isActive;
  final int totalSeconds;
  final int remainingSeconds;

  const RestTimerState({
    this.isActive = false,
    this.totalSeconds = 90,
    this.remainingSeconds = 90,
  });

  double get progress => totalSeconds > 0 ? (remainingSeconds / totalSeconds).clamp(0.0, 1.0) : 0.0;

  RestTimerState copyWith({
    bool? isActive,
    int? totalSeconds,
    int? remainingSeconds,
  }) {
    return RestTimerState(
      isActive: isActive ?? this.isActive,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    );
  }
}

final restTimerProvider = StateNotifierProvider<RestTimerNotifier, RestTimerState>((ref) {
  return RestTimerNotifier();
});

class RestTimerNotifier extends StateNotifier<RestTimerState> {
  Timer? _timer;

  RestTimerNotifier() : super(const RestTimerState());

  void startTimer({int seconds = 90}) {
    _timer?.cancel();
    state = RestTimerState(
      isActive: true,
      totalSeconds: seconds,
      remainingSeconds: seconds,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingSeconds <= 1) {
        timer.cancel();
        state = state.copyWith(isActive: false, remainingSeconds: 0);
        try {
          HapticFeedback.vibrate();
        } catch (_) {}
      } else {
        state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
      }
    });
  }

  void addSeconds(int delta) {
    if (!state.isActive) return;
    final newRemaining = (state.remainingSeconds + delta).clamp(5, 600);
    final newTotal = state.totalSeconds < newRemaining ? newRemaining : state.totalSeconds;
    state = state.copyWith(remainingSeconds: newRemaining, totalSeconds: newTotal);
  }

  void stopTimer() {
    _timer?.cancel();
    state = state.copyWith(isActive: false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Active Workout Session in Progress
final activeWorkoutProvider =
    StateNotifierProvider<ActiveWorkoutNotifier, WorkoutSession?>((ref) {
  return ActiveWorkoutNotifier(ref);
});

class ActiveWorkoutNotifier extends StateNotifier<WorkoutSession?> {
  final Ref _ref;
  Timer? _elapsedTimer;
  int _secondsElapsed = 0;

  ActiveWorkoutNotifier(this._ref) : super(null);

  int get secondsElapsed => _secondsElapsed;

  void startWorkout({
    required String name,
    required WorkoutSplit split,
    List<WorkoutExercise>? initialExercises,
  }) {
    _elapsedTimer?.cancel();
    _secondsElapsed = 0;

    final session = WorkoutSession(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      split: split,
      startTime: DateTime.now(),
      durationMinutes: 0,
      exercises: initialExercises ?? [],
      caloriesBurned: 0,
    );

    state = session;

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _secondsElapsed++;
      // update state duration minutes every 60s
      if (_secondsElapsed % 60 == 0 && state != null) {
        state = WorkoutSession(
          id: state!.id,
          name: state!.name,
          split: state!.split,
          startTime: state!.startTime,
          durationMinutes: _secondsElapsed ~/ 60,
          exercises: state!.exercises,
          notes: state!.notes,
          caloriesBurned: _calculateBurn(_secondsElapsed ~/ 60),
        );
      }
    });
  }

  void addExercise(ExerciseInfo info) {
    if (state == null) return;
    final exercises = List<WorkoutExercise>.from(state!.exercises);
    exercises.add(
      WorkoutExercise(
        exerciseInfo: info,
        sets: [
          ExerciseSet(setNumber: 1, weightKg: 20.0, reps: 10),
          ExerciseSet(setNumber: 2, weightKg: 20.0, reps: 10),
          ExerciseSet(setNumber: 3, weightKg: 20.0, reps: 10),
        ],
      ),
    );

    _updateExercises(exercises);
  }

  void removeExercise(int index) {
    if (state == null || index < 0 || index >= state!.exercises.length) return;
    final exercises = List<WorkoutExercise>.from(state!.exercises);
    exercises.removeAt(index);
    _updateExercises(exercises);
  }

  void addSet(int exerciseIndex) {
    if (state == null || exerciseIndex < 0 || exerciseIndex >= state!.exercises.length) return;
    final exercises = List<WorkoutExercise>.from(state!.exercises);
    final currentExercise = exercises[exerciseIndex];
    final currentSets = List<ExerciseSet>.from(currentExercise.sets);

    // Pre-fill with previous set weight & reps
    final prevWeight = currentSets.isNotEmpty ? currentSets.last.weightKg : 20.0;
    final prevReps = currentSets.isNotEmpty ? currentSets.last.reps : 10;

    currentSets.add(
      ExerciseSet(
        setNumber: currentSets.length + 1,
        weightKg: prevWeight,
        reps: prevReps,
      ),
    );

    exercises[exerciseIndex] = WorkoutExercise(
      exerciseInfo: currentExercise.exerciseInfo,
      sets: currentSets,
    );

    _updateExercises(exercises);
  }

  void removeSet(int exerciseIndex, int setIndex) {
    if (state == null || exerciseIndex < 0 || exerciseIndex >= state!.exercises.length) return;
    final exercises = List<WorkoutExercise>.from(state!.exercises);
    final currentExercise = exercises[exerciseIndex];
    final currentSets = List<ExerciseSet>.from(currentExercise.sets);

    if (setIndex >= 0 && setIndex < currentSets.length) {
      currentSets.removeAt(setIndex);
      // Renumber sets
      for (int i = 0; i < currentSets.length; i++) {
        currentSets[i].setNumber = i + 1;
      }
      exercises[exerciseIndex] = WorkoutExercise(
        exerciseInfo: currentExercise.exerciseInfo,
        sets: currentSets,
      );
      _updateExercises(exercises);
    }
  }

  void updateSet(int exerciseIndex, int setIndex, {double? weightKg, int? reps, bool? isCompleted}) {
    if (state == null || exerciseIndex < 0 || exerciseIndex >= state!.exercises.length) return;
    final exercises = List<WorkoutExercise>.from(state!.exercises);
    final currentExercise = exercises[exerciseIndex];
    final currentSets = List<ExerciseSet>.from(currentExercise.sets);

    if (setIndex >= 0 && setIndex < currentSets.length) {
      final current = currentSets[setIndex];
      final wasCompleted = current.isCompleted;
      currentSets[setIndex] = current.copyWith(
        weightKg: weightKg,
        reps: reps,
        isCompleted: isCompleted,
      );

      exercises[exerciseIndex] = WorkoutExercise(
        exerciseInfo: currentExercise.exerciseInfo,
        sets: currentSets,
      );

      _updateExercises(exercises);

      // Auto start rest timer when a set is newly checked as completed!
      if (isCompleted == true && !wasCompleted) {
        _ref.read(restTimerProvider.notifier).startTimer(seconds: 90);
      }
    }
  }

  void updateNotes(String notes) {
    if (state == null) return;
    state = WorkoutSession(
      id: state!.id,
      name: state!.name,
      split: state!.split,
      startTime: state!.startTime,
      durationMinutes: _secondsElapsed ~/ 60,
      exercises: state!.exercises,
      notes: notes,
      caloriesBurned: _calculateBurn(_secondsElapsed ~/ 60),
    );
  }

  Future<WorkoutSession?> finishWorkout({bool syncWithDailyLogger = true}) async {
    if (state == null) return null;
    _elapsedTimer?.cancel();
    _ref.read(restTimerProvider.notifier).stopTimer();

    final durationMin = (_secondsElapsed / 60).ceil().clamp(1, 360);
    final calories = _calculateBurn(durationMin);

    final finished = WorkoutSession(
      id: state!.id,
      name: state!.name,
      split: state!.split,
      startTime: state!.startTime,
      endTime: DateTime.now(),
      durationMinutes: durationMin,
      exercises: state!.exercises,
      notes: state!.notes,
      caloriesBurned: calories,
    );

    // Save session in history
    await _ref.read(workoutSessionsProvider.notifier).saveSession(finished);

    // Sync with Daily Logger if requested
    if (syncWithDailyLogger) {
      await _syncWithDailyLogger(finished);
    }

    state = null;
    _secondsElapsed = 0;
    return finished;
  }

  void cancelWorkout() {
    _elapsedTimer?.cancel();
    _ref.read(restTimerProvider.notifier).stopTimer();
    state = null;
    _secondsElapsed = 0;
  }

  void _updateExercises(List<WorkoutExercise> exercises) {
    if (state == null) return;
    final durationMin = _secondsElapsed ~/ 60;
    state = WorkoutSession(
      id: state!.id,
      name: state!.name,
      split: state!.split,
      startTime: state!.startTime,
      durationMinutes: durationMin,
      exercises: exercises,
      notes: state!.notes,
      caloriesBurned: _calculateBurn(durationMin),
    );
  }

  int _calculateBurn(int durationMin) {
    final profile = _ref.read(userProfileProvider).value;
    final userWeight = profile?.profileStartWeight ?? 80.0;
    final isSwim = state?.split == WorkoutSplit.cardio &&
        state!.exercises.any((e) => e.exerciseInfo.id == 'cardio_swimming');

    if (isSwim) {
      return PhysicalActivityType.swimming.calculateBurn(
        weightKg: userWeight,
        durationMinutes: durationMin,
      );
    }

    return PhysicalActivityType.weightlifting.calculateBurn(
      weightKg: userWeight,
      durationMinutes: durationMin,
    );
  }

  Future<void> _syncWithDailyLogger(WorkoutSession finished) async {
    try {
      final entries = _ref.read(dailyEntriesProvider).value ?? [];
      final today = DateTime.now();
      final todayEntry = entries.where((e) {
        return e.entryDate.year == today.year &&
            e.entryDate.month == today.month &&
            e.entryDate.day == today.day;
      }).firstOrNull;

      final isSwim = finished.split == WorkoutSplit.cardio &&
          finished.exercises.any((e) => e.exerciseInfo.id == 'cardio_swimming');

      final summaryNote =
          '🏋️ ${finished.name} (${finished.exercises.length} exerciții, ${finished.totalCompletedSets} serii, '
          'Volum: ${finished.totalVolumeKg.toStringAsFixed(0)} kg, ${finished.durationMinutes} min)';

      if (todayEntry != null) {
        // Update existing entry with added burn
        final existingOut = todayEntry.caloriesOut ?? 0;
        final newOut = existingOut + finished.caloriesBurned;
        final updatedNotes = todayEntry.notes != null && todayEntry.notes!.isNotEmpty
            ? '${todayEntry.notes}\n$summaryNote'
            : summaryNote;

        final updatedEntry = todayEntry.copyWith(
          caloriesOut: newOut,
          swimming: todayEntry.swimming || isSwim,
          notes: updatedNotes,
        );
        final dailyRepo = _ref.read(dailyEntryRepositoryProvider);
        await dailyRepo.saveDailyEntry(updatedEntry, existingEntries: entries);
        _ref.invalidate(dailyEntriesProvider);
      }
    } catch (_) {
      // Soft fail, user still has the workout saved locally
    }
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    super.dispose();
  }
}
