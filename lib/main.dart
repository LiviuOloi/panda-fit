import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_colors.dart';
import 'core/network/supabase_client.dart';
import 'core/theme/app_theme.dart';
import 'features/daily_logger/presentation/daily_logger_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/missions/presentation/missions_screen.dart';
import 'features/nutrition_guide/presentation/nutrition_guide_screen.dart';
import 'features/profile/presentation/profile_screen.dart';

import 'features/auth/presentation/session_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseService.initialize();

  runApp(
    const ProviderScope(
      child: PandaFitApp(),
    ),
  );
}

class PandaFitApp extends StatelessWidget {
  const PandaFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PandaFit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SessionGate(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(onQuickLogPressed: () => setState(() => _currentIndex = 1)),
      DailyLoggerScreen(onSaved: () => setState(() => _currentIndex = 0)),
      const MissionsScreen(),
      const NutritionGuideScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.glassBorder, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.emerald.withValues(alpha: 0.25),
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.dashboard, color: AppColors.emerald),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.edit_calendar_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.edit_calendar, color: AppColors.emerald),
              label: 'Log',
            ),
            NavigationDestination(
              icon: Icon(Icons.flag_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.flag, color: AppColors.emerald),
              label: 'Missions',
            ),
            NavigationDestination(
              icon: Icon(Icons.restaurant_menu_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.restaurant_menu, color: AppColors.emerald),
              label: 'Nutrition',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.person, color: AppColors.emerald),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
