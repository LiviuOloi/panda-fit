import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/panda_button.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../missions/domain/mission_model.dart';
import '../../profile/domain/profile_model.dart';
import '../../profile/presentation/profile_controller.dart';
import '../domain/recipe_model.dart';
import 'ai_nutritionist_screen.dart';
import 'custom_recipe_dialog.dart';

class NutritionGuideScreen extends ConsumerWidget {
  const NutritionGuideScreen({super.key});

  void _openAiNutritionist(BuildContext context, UserProfile profile, Mission activeMission) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AiNutritionistScreen(
          profile: profile,
          activeMission: activeMission,
        ),
      ),
    );
  }

  void _openCustomRecipeDialog(BuildContext context, [MealRecipe? recipe]) {
    showDialog<void>(
      context: context,
      builder: (_) => CustomRecipeDialog(existingRecipe: recipe),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final recipesAsync = ref.watch(allRecipesProvider);

    final profile = profileAsync.valueOrNull ??
        UserProfile(
          id: user?.id ?? 'demo',
          username: 'panda_user',
          firstName: 'Panda',
          lastName: 'Member',
          sex: 'MALE',
          birthDate: DateTime(1995, 1, 1),
          heightCm: 180.0,
          profileStartWeight: 98.4,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    final activeMission = Mission(
      id: 'm-1',
      userId: profile.id,
      missionType: MissionType.cutting,
      missionStartWeight: profile.profileStartWeight,
      targetWeight: (profile.profileStartWeight - 5.0),
      startedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'NUTRITION & AI COACH',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: AppColors.emerald,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Glycemic Food Matrix',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),

              // AI Nutritionist Feature Banner
              GlassCard(
                borderColor: AppColors.emerald.withValues(alpha: 0.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.emerald.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.auto_awesome, color: AppColors.emeraldLight, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Panda AI Nutritionist',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Tailored meal plans adapted to your biometrics & preferences',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    PandaButton(
                      label: '✨ Open Panda AI Nutritionist',
                      icon: Icons.chat_bubble_outline,
                      width: double.infinity,
                      onPressed: () => _openAiNutritionist(context, profile, activeMission),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Weighing Protocol Card
              GlassCard(
                borderColor: AppColors.cyan.withValues(alpha: 0.4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.scale, color: AppColors.cyan, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Strict Weighing Protocol',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildProtocolItem('Meat / Poultry / Fish', 'Weigh in RAW / uncooked state (moisture loss varies).'),
                    _buildProtocolItem('Rice / Grains / Pasta', 'Weigh in DRY / uncooked state (e.g. 100g-125g dry rice).'),
                    _buildProtocolItem('Vegetables', 'Weigh FROZEN / raw state for accurate glycemic fiber math.'),
                    _buildProtocolItem('Cooking Oils', 'Measured strictly in grams/ml (never unmeasured).'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // User's Custom Meals Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Personal Menus',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _openCustomRecipeDialog(context),
                    icon: const Icon(Icons.add, size: 18, color: AppColors.emerald),
                    label: const Text('+ New Meal', style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              recipesAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.emerald)),
                  ),
                ),
                error: (err, _) => Center(
                  child: Text('Error loading recipes: $err', style: const TextStyle(color: AppColors.rose)),
                ),
                data: (recipes) {
                  if (recipes.isEmpty) {
                    return GlassCard(
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.restaurant, color: AppColors.textMuted, size: 36),
                            const SizedBox(height: 8),
                            const Text(
                              'No recipes saved yet.',
                              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Create a meal manually or ask Panda AI to propose recipes!',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            PandaButton(
                              label: 'Create First Meal',
                              icon: Icons.add,
                              variant: PandaButtonVariant.outline,
                              onPressed: () => _openCustomRecipeDialog(context),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: recipes.map((r) => _buildRecipeCard(context, ref, r)).toList(),
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

  Widget _buildRecipeCard(BuildContext context, WidgetRef ref, MealRecipe recipe) {
    final isCustom = recipe.userId != null && recipe.userId!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isCustom
                            ? AppColors.cyan.withValues(alpha: 0.2)
                            : AppColors.emerald.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isCustom ? 'PERSONAL · ${recipe.category}' : recipe.category,
                        style: TextStyle(
                          color: isCustom ? AppColors.cyanLight : AppColors.emeraldLight,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      recipe.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (isCustom)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textMuted),
                        onPressed: () => _openCustomRecipeDialog(context, recipe),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.rose),
                        onPressed: () async {
                          final repo = ref.read(recipesRepositoryProvider);
                          await repo.deleteCustomRecipe(recipe.id);
                          ref.invalidate(allRecipesProvider);
                        },
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${recipe.calories} kcal · ${recipe.proteinG ?? 0}g P · ${recipe.carbsG ?? 0}g C · ${recipe.fatG ?? 0}g F',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.emeraldLight,
              ),
            ),
            const SizedBox(height: 10),
            const Divider(color: AppColors.surfaceElevated, height: 1),
            const SizedBox(height: 8),
            ...recipe.ingredients.map(
              (ing) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Text(
                  '• ${ing.name}: ${ing.amount} (${ing.state})',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProtocolItem(String label, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.emerald,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.3),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
