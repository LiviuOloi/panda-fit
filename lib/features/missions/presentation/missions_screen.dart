import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/panda_button.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../missions/domain/mission_model.dart';
import '../../profile/presentation/profile_controller.dart';
import 'new_mission_dialog.dart';

final allMissionsProvider = FutureProvider<List<Mission>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final repo = ref.watch(missionsRepositoryProvider);
  return await repo.fetchAllMissions(user.id);
});

class MissionsScreen extends ConsumerWidget {
  const MissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final missionAsync = ref.watch(activeMissionProvider);
    final entriesAsync = ref.watch(dailyEntriesProvider);
    final historyAsync = ref.watch(allMissionsProvider);

    final profile = profileAsync.value;
    final activeMission = missionAsync.value;
    final entries = entriesAsync.value ?? [];

    final startWeight = activeMission?.missionStartWeight ?? (profile?.profileStartWeight ?? 100.0);
    final latestEntry = entries.isNotEmpty ? entries.first : null;
    final currentWeight = latestEntry?.weight ?? startWeight;
    final isAccomplished = activeMission != null && activeMission.checkAccomplishment(currentWeight);
    final progress = activeMission != null ? activeMission.progress(currentWeight) : 0.0;
    final isCutting = activeMission?.missionType == MissionType.cutting;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'GOALS & PHASES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: AppColors.emerald,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Missions Engine',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),

              // Accomplishment Celebration Banner
              if (isAccomplished)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.emerald.withValues(alpha: 0.25),
                        AppColors.cyan.withValues(alpha: 0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.emerald, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 32)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'MISSION ACCOMPLISHED!',
                              style: TextStyle(
                                color: AppColors.emeraldLight,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'You reached ${currentWeight.toStringAsFixed(1)} kg, strictly surpassing the ${activeMission.targetWeight} kg milestone.',
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Active Mission Card
              GlassCard(
                borderColor: isAccomplished
                    ? AppColors.emerald
                    : AppColors.emerald.withValues(alpha: 0.4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.emerald.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'CURRENT ACTIVE MISSION',
                            style: TextStyle(
                              color: AppColors.emeraldLight,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isAccomplished ? AppColors.emerald : AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isAccomplished ? 'ACCOMPLISHED' : 'IN PROGRESS',
                            style: TextStyle(
                              color: isAccomplished ? Colors.white : AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      activeMission != null
                          ? (isCutting ? 'Cutting Phase — Sustainable Fat Loss' : 'Bulking Phase — Lean Muscle Mass')
                          : 'No active mission configured',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      activeMission != null
                          ? 'Mission Goal: Reach strictly ${isCutting ? "<" : ">"} ${activeMission.targetWeight} kg to trigger accomplishment.'
                          : 'Configure your first mission to track milestone progress.',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 20),

                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 12,
                        backgroundColor: AppColors.surfaceElevated,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emerald),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Start: $startWeight kg', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        Text('Current: $currentWeight kg', style: const TextStyle(color: AppColors.cyan, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text(
                          activeMission != null ? 'Strict Target: ${isCutting ? "<" : ">"} ${activeMission.targetWeight} kg' : '-',
                          style: const TextStyle(color: AppColors.emeraldLight, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Configure New Mission Button
              PandaButton(
                label: 'Configure Next Mission',
                icon: isAccomplished ? Icons.rocket_launch : Icons.flag_outlined,
                variant: isAccomplished ? PandaButtonVariant.primary : PandaButtonVariant.secondary,
                width: double.infinity,
                onPressed: () => _handleConfigureMission(
                  context,
                  ref,
                  currentWeight: currentWeight,
                  activeMission: activeMission,
                  isAccomplished: isAccomplished,
                ),
              ),
              const SizedBox(height: 24),

              // Domain Invariant Rule Note Card
              const GlassCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_outlined, color: AppColors.cyan, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Strict Inequality Invariant',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'A cutting mission requires weighing strictly less than the target weight (e.g. \u2264 94.9 kg for a 95.0 kg target). Tying the target does not trigger accomplishment.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Past Missions History Section
              const Text(
                'Missions Milestone History',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              historyAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(color: AppColors.emerald),
                  ),
                ),
                error: (err, _) => Text(
                  'Could not load missions history: $err',
                  style: const TextStyle(color: AppColors.rose, fontSize: 12),
                ),
                data: (missions) {
                  final pastMissions = missions.where((m) => m.id != activeMission?.id).toList();

                  if (pastMissions.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.history, color: AppColors.textMuted, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No archived missions yet. Complete your current phase to record milestones.',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: pastMissions.map((m) {
                      final isCut = m.missionType == MissionType.cutting;
                      final isArchivedAccomplished = m.status == MissionStatus.accomplished;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isArchivedAccomplished
                                ? AppColors.emerald.withValues(alpha: 0.4)
                                : AppColors.glassBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(isCut ? '✂️' : '🦁', style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${isCut ? "Cut" : "Bulk"}: ${m.missionStartWeight} kg → ${m.targetWeight} kg',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Started: ${m.startedAt.toIso8601String().split("T").first}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isArchivedAccomplished
                                    ? AppColors.emerald.withValues(alpha: 0.2)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                m.status.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isArchivedAccomplished ? AppColors.emeraldLight : AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleConfigureMission(
    BuildContext context,
    WidgetRef ref, {
    required double currentWeight,
    required Mission? activeMission,
    required bool isAccomplished,
  }) async {
    if (activeMission != null && !isAccomplished) {
      // Prompt user with active mission replacement confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.glassBorder),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.amber, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Active Mission in Progress',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          content: Text(
            'You already have an active ${activeMission.missionType.name.toUpperCase()} mission in progress (${activeMission.missionStartWeight} kg → ${activeMission.targetWeight} kg).\n\nStarting a new mission will terminate the current active mission and archive it. Are you sure you want to proceed?',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep Current Mission', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.rose.withValues(alpha: 0.2),
                foregroundColor: AppColors.rose,
                side: const BorderSide(color: AppColors.rose),
                elevation: 0,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Abandon & Start New'),
            ),
          ],
        ),
      );

      if (confirmed == true && context.mounted) {
        _openNewMissionDialog(
          context,
          ref,
          currentWeight: currentWeight,
          activeMission: activeMission,
          isAccomplished: false,
        );
      }
    } else {
      _openNewMissionDialog(
        context,
        ref,
        currentWeight: currentWeight,
        activeMission: activeMission,
        isAccomplished: isAccomplished,
      );
    }
  }

  void _openNewMissionDialog(
    BuildContext context,
    WidgetRef ref, {
    required double currentWeight,
    required Mission? activeMission,
    required bool isAccomplished,
  }) {
    showDialog<bool>(
      context: context,
      builder: (_) => NewMissionDialog(
        currentWeight: currentWeight,
        previousMission: activeMission,
        isPreviousAccomplished: isAccomplished,
      ),
    ).then((created) {
      if (created == true) {
        ref.invalidate(activeMissionProvider);
        ref.invalidate(allMissionsProvider);
      }
    });
  }
}
