import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../main.dart';
import '../../profile/presentation/onboarding_wizard_screen.dart';
import '../../profile/presentation/profile_controller.dart';
import 'auth_controller.dart';
import 'auth_screen.dart';

class SessionGate extends ConsumerWidget {
  const SessionGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return const AuthScreen();
    }

    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.emerald),
              ),
              SizedBox(height: 16),
              Text(
                'SYNCING METRICS...',
                style: TextStyle(
                  color: AppColors.emeraldLight,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppColors.rose, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Connection or Profile Error',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => ref.invalidate(userProfileProvider),
                  child: const Text('Retry'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
                  child: const Text('Sign Out', style: TextStyle(color: AppColors.rose)),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (profile) {
        if (profile == null) {
          // User authenticated but hasn't completed Onboarding yet
          return const OnboardingWizardScreen();
        }
        // Profile exists, load full app
        return const MainNavigationScreen();
      },
    );
  }
}
