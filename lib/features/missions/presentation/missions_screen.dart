import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/panda_button.dart';
import '../../missions/domain/mission_model.dart';
import '../../profile/presentation/profile_controller.dart';

class MissionsScreen extends ConsumerWidget {
  const MissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final missionAsync = ref.watch(activeMissionProvider);
    final entriesAsync = ref.watch(dailyEntriesProvider);

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

              // Active Mission Card
              GlassCard(
                borderColor: AppColors.emerald.withValues(alpha: 0.4),
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
              const SizedBox(height: 24),

              // Configure New Mission Button
              PandaButton(
                label: 'Configure Next Mission',
                icon: Icons.flag_outlined,
                variant: PandaButtonVariant.secondary,
                width: double.infinity,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Your active mission is already in progress. Log daily weights to track milestones!'),
                      backgroundColor: AppColors.emerald,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
