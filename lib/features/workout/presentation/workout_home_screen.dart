import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/panda_button.dart';
import '../domain/exercise_library.dart';
import '../domain/exercise_model.dart';
import 'active_workout_screen.dart';
import 'workout_controller.dart';

class WorkoutHomeScreen extends ConsumerStatefulWidget {
  const WorkoutHomeScreen({super.key});

  @override
  ConsumerState<WorkoutHomeScreen> createState() => _WorkoutHomeScreenState();
}

class _WorkoutHomeScreenState extends ConsumerState<WorkoutHomeScreen> {
  final DateFormat _dateFormat = DateFormat('EEEE, d MMMM yyyy', 'ro');

  void _startWorkoutFromTemplate(WorkoutTemplate template) {
    ref.read(activeWorkoutProvider.notifier).startWorkout(
          name: template.name,
          split: template.split,
          initialExercises: template.buildInitialExercises(),
        );

    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (context) => const ActiveWorkoutScreen()),
    );
  }

  void _startCustomWorkout() {
    ref.read(activeWorkoutProvider.notifier).startWorkout(
          name: 'Antrenament Custom',
          split: WorkoutSplit.custom,
          initialExercises: [],
        );

    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (context) => const ActiveWorkoutScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeWorkout = ref.watch(activeWorkoutProvider);
    final sessionsAsync = ref.watch(workoutSessionsProvider);
    final sessions = sessionsAsync.value ?? [];

    // Aggregate stats
    final totalSessions = sessions.length;
    final totalVolume = sessions.fold<double>(0.0, (acc, s) => acc + s.totalVolumeKg);
    final totalCalories = sessions.fold<int>(0, (acc, s) => acc + s.caloriesBurned);
    final avgDuration = totalSessions > 0
        ? (sessions.fold<int>(0, (acc, s) => acc + s.durationMinutes) / totalSessions).round()
        : 0;

    return Scaffold(
      backgroundColor: AppColors.background,
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
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.fitness_center, color: AppColors.emerald, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'PANDAFIT · WORKOUT LOGGER',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: AppColors.emerald,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Jurnal de Sală',
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
                    label: 'Antrenament Nou',
                    icon: Icons.add,
                    onPressed: _startCustomWorkout,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Active Workout Banner (if in progress)
              if (activeWorkout != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.emerald, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emerald.withValues(alpha: 0.25),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.emerald.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.flash_on, color: AppColors.emerald, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ANTRENAMENT ÎN DESFĂȘURARE',
                                style: TextStyle(
                                  color: AppColors.emerald,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                activeWorkout.name,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${activeWorkout.exercises.length} exerciții · ${activeWorkout.totalCompletedSets} serii gata',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                      PandaButton(
                        label: 'Continuă',
                        icon: Icons.play_arrow,
                        variant: PandaButtonVariant.primary,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (context) => const ActiveWorkoutScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // KPI Stats Grid
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Antrenamente',
                      '$totalSessions',
                      'sesiuni încheiate',
                      Icons.check_circle_outline,
                      AppColors.emerald,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      'Volum Total',
                      '${(totalVolume / 1000).toStringAsFixed(1)} t',
                      '${totalVolume.toStringAsFixed(0)} kg ridicați',
                      Icons.fitness_center,
                      AppColors.cyan,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Calorii Active',
                      '$totalCalories',
                      'kcal arse estimate',
                      Icons.local_fire_department_outlined,
                      AppColors.amber,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      'Durată Medie',
                      '$avgDuration min',
                      'pe sesiune de sală',
                      Icons.timer_outlined,
                      AppColors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Routine Templates Section
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Rutine Rapide (Quick Start)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Alege o rutină structurată pentru a începe antrenamentul cu exercițiile și seriile pre-configurate.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 175,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: ExerciseLibrary.presetTemplates.length,
                  itemBuilder: (context, index) {
                    final template = ExerciseLibrary.presetTemplates[index];
                    return _buildTemplateCard(template);
                  },
                ),
              ),
              const SizedBox(height: 28),

              // Workout History List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Istoric Antrenamente',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '$totalSessions înregistrări',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (sessions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(28),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.fitness_center_outlined,
                        size: 44,
                        color: AppColors.emerald.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Niciun antrenament înregistrat încă',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Alege o rutină din cele de mai sus sau apasă „Antrenament Nou” pentru a începe primul tău jurnal de sală!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    return _buildHistoryCard(session);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    String subtitle,
    IconData icon,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Icon(icon, color: accentColor, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(WorkoutTemplate template) {
    return Container(
      width: 250,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.flash_on, color: AppColors.emerald, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  template.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              template.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${template.exerciseIds.length} exerciții recomandate',
            style: const TextStyle(fontSize: 10, color: AppColors.emerald),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text(
                'Start Rutină',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _startWorkoutFromTemplate(template),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(WorkoutSession session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.emerald.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.fitness_center, color: AppColors.emerald, size: 20),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                session.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              '${session.durationMinutes} min',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.cyan),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _dateFormat.format(session.startTime),
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildHistoryTag('${session.exercises.length} exerciții'),
                const SizedBox(width: 6),
                _buildHistoryTag('${session.totalCompletedSets} serii'),
                const SizedBox(width: 6),
                _buildHistoryTag('${session.totalVolumeKg.toStringAsFixed(0)} kg volum'),
                const SizedBox(width: 6),
                _buildHistoryTag('~${session.caloriesBurned} kcal'),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 18),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.surfaceElevated,
                title: const Text(
                  'Ștergi antrenamentul?',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
                ),
                content: const Text(
                  'Această sesiune va fi ștearsă din istoricul tău de antrenamente.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Anulează', style: TextStyle(color: AppColors.textMuted)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Șterge', style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              await ref.read(workoutSessionsProvider.notifier).deleteSession(session.id);
            }
          },
        ),
      ),
    );
  }

  Widget _buildHistoryTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
      ),
    );
  }
}
