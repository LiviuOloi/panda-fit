import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/panda_button.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../missions/domain/mission_model.dart';
import '../../profile/domain/profile_model.dart';
import '../../profile/presentation/profile_controller.dart';
import '../data/gemini_api_key_provider.dart';
import '../domain/recipe_model.dart';
import 'ai_nutritionist_screen.dart';
import 'custom_recipe_dialog.dart';
import 'gemini_api_key_dialog.dart';

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

  void _openApiKeyDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const GeminiApiKeyDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final recipesAsync = ref.watch(allRecipesProvider);
    final apiKeyAsync = ref.watch(geminiApiKeyProvider);
    final hasApiKey = apiKeyAsync.valueOrNull != null && apiKeyAsync.valueOrNull!.isNotEmpty;

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PANDA EATS AI',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: AppColors.emerald,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Glycemic Food Matrix',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.key,
                      color: hasApiKey ? AppColors.emerald : AppColors.amber,
                      size: 22,
                    ),
                    tooltip: hasApiKey ? 'Gemini AI Key Configured' : 'Setup Free Gemini AI Key',
                    onPressed: () => _openApiKeyDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Gemini Live AI Setup / Status Banner
              if (!hasApiKey)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  child: GlassCard(
                    borderColor: AppColors.amber.withValues(alpha: 0.6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.amber.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.bolt, color: AppColors.amber, size: 22),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '⚡ Activate Live AI & Web Search',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '100% Free · Google Gemini 1.5/2.0 Flash · No credit card required',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Connect your free Google AI Studio key to unlock dynamic unlimited recipes, real-time nutrition coaching, and web search.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.3),
                        ),
                        const SizedBox(height: 14),
                        PandaButton(
                          label: 'Setup Free Gemini API Key (30 sec)',
                          icon: Icons.key,
                          variant: PandaButtonVariant.secondary,
                          width: double.infinity,
                          onPressed: () => _openApiKeyDialog(context),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.emerald.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.emerald, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          '⚡ Panda Live AI Active (Google Gemini Flash)',
                          style: TextStyle(
                            color: AppColors.emeraldLight,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _openApiKeyDialog(context),
                        child: const Text('Manage Key', style: TextStyle(color: AppColors.cyan, fontSize: 11)),
                      ),
                    ],
                  ),
                ),

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
                      label: 'Open Panda AI Nutritionist',
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
                    'Planul Tău Alimentar / Mese',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _openCustomRecipeDialog(context),
                        icon: const Icon(Icons.add, size: 18, color: AppColors.emerald),
                        label: const Text('Adaugă Masă', style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.bold)),
                      ),
                      if (recipesAsync.valueOrNull != null && recipesAsync.valueOrNull!.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.delete_sweep_outlined, size: 20, color: AppColors.rose),
                          tooltip: 'Șterge toate mesele din plan',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: AppColors.surface,
                                title: const Text('Ștergi toate mesele?', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                                content: const Text('Toate mesele salvate vor fi șterse din meniul tău personal. Vei putea genera oricând un plan nou cu Panda AI.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Anulează', style: TextStyle(color: AppColors.textSecondary)),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Șterge Tot', style: TextStyle(color: AppColors.rose, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              final repo = ref.read(recipesRepositoryProvider);
                              await repo.clearAllCustomRecipes(user?.id ?? profile.id);
                              ref.invalidate(allRecipesProvider);
                            }
                          },
                        ),
                    ],
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.emerald.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.restaurant_menu, color: AppColors.emeraldLight, size: 36),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Nu ai niciun meniu salvat încă',
                              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Creează-ți un plan alimentar personalizat de la 0 cu antrenorul Panda AI sau configurează-ți mesele manual!',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 18),
                            PandaButton(
                              label: 'Generează Plan cu Panda AI',
                              icon: Icons.auto_awesome,
                              width: double.infinity,
                              onPressed: () => _openAiNutritionist(context, profile, activeMission),
                            ),
                            const SizedBox(height: 10),
                            PandaButton(
                              label: 'Adaugă Masă Manual',
                              icon: Icons.add,
                              variant: PandaButtonVariant.outline,
                              width: double.infinity,
                              onPressed: () => _openCustomRecipeDialog(context),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final totalCal = recipes.fold<int>(0, (sum, r) => sum + r.calories);
                  final totalP = recipes.fold<double>(0.0, (sum, r) => sum + (r.proteinG ?? 0));
                  final totalC = recipes.fold<double>(0.0, (sum, r) => sum + (r.carbsG ?? 0));
                  final totalF = recipes.fold<double>(0.0, (sum, r) => sum + (r.fatG ?? 0));

                  return Column(
                    children: [
                      // Total Nutrition Header Summary
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Plan Zilnic:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                            ),
                            Text(
                              '$totalCal kcal · ${totalP.toStringAsFixed(0)}g P · ${totalC.toStringAsFixed(0)}g C · ${totalF.toStringAsFixed(0)}g F',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.emeraldLight),
                            ),
                          ],
                        ),
                      ),
                      ...recipes.map((r) => _buildRecipeCard(context, ref, r)),
                    ],
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
