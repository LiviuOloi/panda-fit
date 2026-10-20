import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/panda_button.dart';
import '../domain/exercise_model.dart';
import 'workout_controller.dart';
import 'widgets/exercise_picker_dialog.dart';
import 'widgets/rest_timer_banner.dart';

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  Timer? _secondTicker;
  int _seconds = 0;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _seconds = ref.read(activeWorkoutProvider.notifier).secondsElapsed;
    _secondTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _seconds++;
        });
      }
    });

    final currentNotes = ref.read(activeWorkoutProvider)?.notes;
    if (currentNotes != null) {
      _notesController.text = currentNotes;
    }
  }

  @override
  void dispose() {
    _secondTicker?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _handleFinish() async {
    final workout = ref.read(activeWorkoutProvider);
    if (workout == null) return;

    bool syncDaily = true;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: AppColors.surfaceElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: AppColors.glassBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.emoji_events, color: AppColors.amber, size: 28),
                        SizedBox(width: 10),
                        Text(
                          'Antrenament Finalizat!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow(
                            'Durată Totală',
                            _formatDuration(_seconds),
                            AppColors.textPrimary,
                          ),
                          const Divider(color: AppColors.glassBorder),
                          _buildSummaryRow(
                            'Volum Total Ridicat',
                            '${workout.totalVolumeKg.toStringAsFixed(0)} kg',
                            AppColors.emerald,
                          ),
                          const Divider(color: AppColors.glassBorder),
                          _buildSummaryRow(
                            'Serii Încheiate',
                            '${workout.totalCompletedSets} serii',
                            AppColors.cyan,
                          ),
                          const Divider(color: AppColors.glassBorder),
                          _buildSummaryRow(
                            'Consum Estimat (MET)',
                            '~${workout.caloriesBurned} kcal',
                            AppColors.amber,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: syncDaily,
                      onChanged: (val) {
                        setDialogState(() => syncDaily = val ?? true);
                      },
                      activeColor: AppColors.emerald,
                      title: const Text(
                        'Sincronizează cu Jurnalul de Azi (Daily Logger)',
                        style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      ),
                      subtitle: const Text(
                        'Adaugă caloriile active și nota antrenamentului în jurnalul de astăzi.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, false),
                          child: const Text(
                            'Continuă Antrenamentul',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                        const SizedBox(width: 10),
                        PandaButton(
                          label: 'Salvează în Istoric',
                          icon: Icons.check,
                          onPressed: () => Navigator.pop(dialogCtx, true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (shouldSave == true && mounted) {
      await HapticFeedback.heavyImpact();
      if (!mounted) return;
      await ref.read(activeWorkoutProvider.notifier).finishWorkout(
            syncWithDailyLogger: syncDaily,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Antrenamentul a fost salvat cu succes în istoric!'),
            backgroundColor: AppColors.emerald,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  Widget _buildSummaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text(
          'Abandonezi antrenamentul?',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
        ),
        content: const Text(
          'Toate datele din această sesiune vor fi anulate și nu vor fi salvate.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nu, continuă', style: TextStyle(color: AppColors.emerald)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abandonează', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ref.read(activeWorkoutProvider.notifier).cancelWorkout();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workout = ref.watch(activeWorkoutProvider);
    if (workout == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Niciun antrenament activ')),
        body: const Center(
          child: Text('Niciun antrenament în desfășurare.'),
        ),
      );
    }

    final totalSets =
        workout.exercises.fold<int>(0, (acc, e) => acc + e.sets.length);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              workout.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${workout.split.displayName} · ${_formatDuration(_seconds)}',
              style: const TextStyle(fontSize: 11, color: AppColors.emerald),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Abandonează antrenamentul',
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
            onPressed: _handleCancel,
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.check, size: 18),
              label: const Text(
                'Finalizează',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: _handleFinish,
            ),
          ),
        ],
      ),
      bottomNavigationBar: const RestTimerBanner(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Summary Strip
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildQuickKpi('Timp Scurs', _formatDuration(_seconds), AppColors.textPrimary),
                  Container(height: 28, width: 1, color: AppColors.glassBorder),
                  _buildQuickKpi(
                    'Volum Ridicat',
                    '${workout.totalVolumeKg.toStringAsFixed(0)} kg',
                    AppColors.emerald,
                  ),
                  Container(height: 28, width: 1, color: AppColors.glassBorder),
                  _buildQuickKpi(
                    'Serii Făcute',
                    '${workout.totalCompletedSets} / $totalSets',
                    AppColors.cyan,
                  ),
                  Container(height: 28, width: 1, color: AppColors.glassBorder),
                  _buildQuickKpi(
                    'Consum',
                    '~${workout.caloriesBurned} kcal',
                    AppColors.amber,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Exercises List
            ...workout.exercises.asMap().entries.map((entry) {
              final exIndex = entry.key;
              final exercise = entry.value;
              return _buildExerciseCard(exIndex, exercise);
            }),

            const SizedBox(height: 12),

            // Add Exercise Button
            SizedBox(
              width: double.infinity,
              child: PandaButton(
                label: 'Adaugă Exercițiu în Sesiune',
                icon: Icons.add_circle_outline,
                variant: PandaButtonVariant.secondary,
                onPressed: () async {
                  final chosen = await ExercisePickerDialog.show(context);
                  if (chosen != null) {
                    ref.read(activeWorkoutProvider.notifier).addExercise(chosen);
                  }
                },
              ),
            ),
            const SizedBox(height: 20),

            // Workout Notes Field
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.notes, color: AppColors.textSecondary, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Note despre Antrenament',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    onChanged: (val) {
                      ref.read(activeWorkoutProvider.notifier).updateNotes(val);
                    },
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText:
                          'Ex: Am simțit forță mare la piept, am mărit pauza la 2 min, hidratare bună...',
                      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.glassBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.glassBorder),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickKpi(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildExerciseCard(int exIndex, WorkoutExercise exercise) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exercise Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        exercise.exerciseInfo.muscleGroup.icon,
                        color: AppColors.emerald,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exercise.exerciseInfo.nameRo,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${exercise.exerciseInfo.nameEn} · ${exercise.exerciseInfo.equipment}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Șterge acest exercițiu',
                  icon: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
                  onPressed: () {
                    ref.read(activeWorkoutProvider.notifier).removeExercise(exIndex);
                  },
                ),
              ],
            ),
          ),

          // Sets Table Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 38,
                  child: Text(
                    'SET',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: Text(
                    'GREUTATE (KG)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: Text(
                    'REPETĂRI',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                SizedBox(
                  width: 44,
                  child: Text(
                    'GATA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                SizedBox(width: 28), // space for delete icon
              ],
            ),
          ),

          // Sets List
          ...exercise.sets.asMap().entries.map((setEntry) {
            final setIndex = setEntry.key;
            final set = setEntry.value;
            return _buildSetRow(exIndex, setIndex, set);
          }),

          // Add Set Button
          Padding(
            padding: const EdgeInsets.all(12),
            child: InkWell(
              onTap: () {
                ref.read(activeWorkoutProvider.notifier).addSet(exIndex);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: AppColors.emerald, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Adaugă o Serie',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.emerald,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetRow(int exIndex, int setIndex, ExerciseSet set) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      color: set.isCompleted
          ? AppColors.emerald.withValues(alpha: 0.08)
          : Colors.transparent,
      child: Row(
        children: [
          // Set badge
          Container(
            width: 38,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: set.isCompleted
                  ? AppColors.emerald.withValues(alpha: 0.25)
                  : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '#${set.setNumber}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: set.isCompleted ? AppColors.emerald : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Weight Input
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 36,
              child: TextFormField(
                key: ValueKey('weight_${exIndex}_${setIndex}_${set.weightKg}'),
                initialValue: set.weightKg.toStringAsFixed(1),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) {
                  final parsed = double.tryParse(val);
                  if (parsed != null && parsed >= 0) {
                    ref.read(activeWorkoutProvider.notifier).updateSet(
                          exIndex,
                          setIndex,
                          weightKg: parsed,
                        );
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Reps Input
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 36,
              child: TextFormField(
                key: ValueKey('reps_${exIndex}_${setIndex}_${set.reps}'),
                initialValue: set.reps.toString(),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) {
                  final parsed = int.tryParse(val);
                  if (parsed != null && parsed >= 0) {
                    ref.read(activeWorkoutProvider.notifier).updateSet(
                          exIndex,
                          setIndex,
                          reps: parsed,
                        );
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Checkbox Button
          SizedBox(
            width: 44,
            child: IconButton(
              icon: Icon(
                set.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                color: set.isCompleted ? AppColors.emerald : AppColors.textMuted,
                size: 24,
              ),
              onPressed: () {
                final willBeCompleted = !set.isCompleted;
                if (willBeCompleted) {
                  HapticFeedback.mediumImpact();
                } else {
                  HapticFeedback.selectionClick();
                }
                ref.read(activeWorkoutProvider.notifier).updateSet(
                      exIndex,
                      setIndex,
                      isCompleted: willBeCompleted,
                    );
              },
            ),
          ),

          // Remove set
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: AppColors.textMuted, size: 18),
            onPressed: () {
              ref.read(activeWorkoutProvider.notifier).removeSet(exIndex, setIndex);
            },
          ),
        ],
      ),
    );
  }
}
