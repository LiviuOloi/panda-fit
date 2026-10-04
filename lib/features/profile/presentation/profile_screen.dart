import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/panda_button.dart';
import '../domain/profile_model.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = UserProfile(
      id: 'u-1',
      username: 'liviu_panda',
      firstName: 'Liviu',
      lastName: 'Oloi',
      sex: 'MALE',
      birthDate: DateTime(1994, 6, 15),
      heightCm: 182.0,
      profileStartWeight: 104.2,
      dailyTargetCalories: 2300,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime.now(),
    );

    const hasDailyEntries = true; // Simulating entries exist -> Lock active

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'USER PREFERENCES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: AppColors.emerald,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Profile & Biometrics',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),

              // User Info Card
              GlassCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.emerald.withValues(alpha: 0.2),
                      child: const Icon(Icons.person, size: 36, color: AppColors.emerald),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.fullName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@${profile.username} · ${profile.age} years old',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Profile Start Weight Immutability Guardrail Card
              GlassCard(
                borderColor: hasDailyEntries ? AppColors.amber.withValues(alpha: 0.4) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Profile Starting Weight',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (hasDailyEntries)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.lock, size: 12, color: AppColors.amber),
                                SizedBox(width: 4),
                                Text(
                                  'LOCKED',
                                  style: TextStyle(
                                    color: AppColors.amber,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${profile.profileStartWeight} kg',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.emeraldLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Domain Invariant: Immutable once first daily entry is logged. Subsequent daily entries do not overwrite start weight.',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Target & Biometrics Details
              GlassCard(
                child: Column(
                  children: [
                    _buildDetailRow('Height', '${profile.heightCm} cm'),
                    const Divider(color: AppColors.surfaceElevated),
                    _buildDetailRow('Sex', profile.sex),
                    const Divider(color: AppColors.surfaceElevated),
                    _buildDetailRow('Daily Target Calories', '${profile.dailyTargetCalories} kcal'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Sign out / Settings
              PandaButton(
                label: 'Sign Out Session',
                icon: Icons.logout,
                variant: PandaButtonVariant.outline,
                width: double.infinity,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14)),
        ],
      ),
    );
  }
}
