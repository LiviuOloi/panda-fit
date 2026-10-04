import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/calculation_engine.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/panda_button.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../missions/domain/mission_model.dart';
import '../../profile/domain/profile_model.dart';
import '../data/ai_nutrition_service.dart';
import '../data/gemini_api_key_provider.dart';
import '../data/recipes_repository.dart';
import '../domain/recipe_model.dart';
import 'gemini_api_key_dialog.dart';

final recipesRepositoryProvider = Provider<RecipesRepository>((ref) {
  return RecipesRepository();
});

final allRecipesProvider = FutureProvider<List<MealRecipe>>((ref) async {
  final user = ref.watch(currentUserProvider);
  final repo = ref.watch(recipesRepositoryProvider);
  return await repo.fetchAllRecipes(user?.id);
});

class AiNutritionistScreen extends ConsumerStatefulWidget {
  final UserProfile profile;
  final Mission activeMission;

  const AiNutritionistScreen({
    super.key,
    required this.profile,
    required this.activeMission,
  });

  @override
  ConsumerState<AiNutritionistScreen> createState() => _AiNutritionistScreenState();
}

class _AiNutritionistScreenState extends ConsumerState<AiNutritionistScreen> {
  final _aiService = AiNutritionService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  bool _isLoading = false;
  final List<Map<String, dynamic>> _messages = [];
  final List<MealRecipe> _generatedRecipes = [];

  @override
  void initState() {
    super.initState();
    final maintenance = CalculationEngine.calculateMaintenanceCalories(
      weightKg: widget.profile.profileStartWeight,
      heightCm: widget.profile.heightCm,
      age: widget.profile.age,
      sex: widget.profile.sex,
    );
    final target = CalculationEngine.calculateRecommendedTargetCalories(
      weightKg: widget.profile.profileStartWeight,
      heightCm: widget.profile.heightCm,
      age: widget.profile.age,
      sex: widget.profile.sex,
      missionType: widget.activeMission.missionType.name,
    );
    final isCutting = widget.activeMission.missionType == MissionType.cutting;

    _messages.add({
      'role': 'ai',
      'text': 'Hello ${widget.profile.firstName}! I am Panda Coach AI 🐼.\n\n📊 **Your Metabolic Analysis:**\n• Weight: ${widget.profile.profileStartWeight} kg · Height: ${widget.profile.heightCm} cm · Age: ${widget.profile.age} yrs\n• **Maintenance Calories (TDEE):** ~$maintenance kcal/day\n• **Recommended Daily Target (${widget.activeMission.missionType.name.toUpperCase()}):** ~$target kcal/day ${isCutting ? '(-450 kcal deficit)' : '(+300 kcal surplus)'}\n\nLet me know your dietary preferences (e.g. no pork, more fish, quick 15-min recipes) and I will craft your ideal glycemic meal plan!',
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = presetText ?? _textController.text.trim();
    if (text.isEmpty || _isLoading) return;

    _textController.clear();
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });

    _scrollToBottom();

    final customApiKey = ref.read(geminiApiKeyProvider).valueOrNull;

    // 1. Generate conversational response
    final history = _messages.map((m) => {'role': m['role'] as String, 'text': m['text'] as String}).toList();
    final reply = await _aiService.chatConsultation(
      history: history,
      userMessage: text,
      profile: widget.profile,
      activeMission: widget.activeMission,
      customApiKey: customApiKey,
    );

    // 2. Generate structured meal proposals if requesting plan
    if (text.toLowerCase().contains('plan') ||
        text.toLowerCase().contains('menu') ||
        text.toLowerCase().contains('meal') ||
        text.toLowerCase().contains('recipe') ||
        text.toLowerCase().contains('cutting') ||
        text.toLowerCase().contains('bulking') ||
        presetText != null) {
      final recipes = await _aiService.generateCustomMealPlan(
        profile: widget.profile,
        activeMission: widget.activeMission,
        userPreferences: text,
        customApiKey: customApiKey,
      );
      _generatedRecipes.clear();
      _generatedRecipes.addAll(recipes);
    }

    if (!mounted) return;

    setState(() {
      _messages.add({'role': 'ai', 'text': reply});
      _isLoading = false;
    });

    _scrollToBottom();
  }

  Future<void> _saveRecipeToUserMenu(MealRecipe recipe) async {
    final user = ref.read(currentUserProvider);
    final userId = user?.id ?? widget.profile.id;

    final userRecipe = MealRecipe(
      id: '',
      userId: userId,
      category: recipe.category,
      title: recipe.title,
      ingredients: recipe.ingredients,
      calories: recipe.calories,
      proteinG: recipe.proteinG,
      carbsG: recipe.carbsG,
      fatG: recipe.fatG,
      instructions: recipe.instructions,
    );

    try {
      final repo = ref.read(recipesRepositoryProvider);
      await repo.createCustomRecipe(userRecipe);

      ref.invalidate(allRecipesProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${recipe.title}" saved to your personal menu!'),
          backgroundColor: AppColors.emerald,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving recipe: $e'),
          backgroundColor: AppColors.rose,
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openApiKeyDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => const GeminiApiKeyDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiKeyAsync = ref.watch(geminiApiKeyProvider);
    final hasApiKey = apiKeyAsync.valueOrNull != null && apiKeyAsync.valueOrNull!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.smart_toy_outlined, color: AppColors.emeraldLight, size: 22),
            SizedBox(width: 8),
            Text(
              'Panda Eats AI Coach',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.key,
              color: hasApiKey ? AppColors.emerald : AppColors.amber,
              size: 22,
            ),
            tooltip: hasApiKey ? 'Gemini Live AI Active' : 'Setup Free Gemini Key',
            onPressed: _openApiKeyDialog,
          ),
        ],
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Chat Messages List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: _messages.length + (_generatedRecipes.isNotEmpty ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _generatedRecipes.isNotEmpty) {
                    return _buildGeneratedRecipesSection();
                  }

                  final msg = _messages[index];
                  final isUser = msg['role'] == 'user';

                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isUser ? AppColors.emerald : AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: isUser ? null : Border.all(color: AppColors.glassBorder),
                      ),
                      child: Text(
                        msg['text'] as String,
                        style: TextStyle(
                          color: isUser ? Colors.white : AppColors.textPrimary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppColors.emerald))),
                    SizedBox(width: 10),
                    Text('Panda AI is computing glycemic formulas...', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),

            // Quick Prompt Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  _buildQuickChip('📊 Maintenance & TDEE Analysis'),
                  _buildQuickChip('🔥 Generate Cutting Plan'),
                  _buildQuickChip('🐟 High-Fish & Salmon Menu'),
                  _buildQuickChip('🚫 Dairy-Free / No Lactose'),
                  _buildQuickChip('⚡ Quick 15-Minute Meals'),
                ],
              ),
            ),

            // Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.glassBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Ask Panda AI about meal ideas or preferences...',
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppColors.emerald),
                    onPressed: () => _sendMessage(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        label: Text(label),
        backgroundColor: AppColors.surfaceElevated,
        labelStyle: const TextStyle(color: AppColors.emeraldLight, fontSize: 12, fontWeight: FontWeight.w600),
        side: const BorderSide(color: AppColors.glassBorder),
        onPressed: () => _sendMessage(label),
      ),
    );
  }

  Widget _buildGeneratedRecipesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            children: [
              Icon(Icons.restaurant_menu, color: AppColors.emeraldLight, size: 18),
              SizedBox(width: 8),
              Text(
                'AI Proposed Meals (Glycemic & Raw Weighed)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        ..._generatedRecipes.map((r) => _buildRecipeProposalCard(r)),
      ],
    );
  }

  Widget _buildRecipeProposalCard(MealRecipe recipe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        borderColor: AppColors.emerald.withValues(alpha: 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    recipe.category,
                    style: const TextStyle(color: AppColors.emeraldLight, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${recipe.calories} kcal',
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              recipe.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              '${recipe.proteinG ?? 0}g P · ${recipe.carbsG ?? 0}g C · ${recipe.fatG ?? 0}g F',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.cyanLight),
            ),
            const SizedBox(height: 10),
            const Divider(color: AppColors.surfaceElevated, height: 1),
            const SizedBox(height: 10),
            ...recipe.ingredients.map(
              (i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  children: [
                    const Text('• ', style: TextStyle(color: AppColors.emerald)),
                    Text('${i.name}: ', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 13)),
                    Text('${i.amount} (${i.state})', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            PandaButton(
              label: 'Save to My Menu',
              icon: Icons.bookmark_add_outlined,
              variant: PandaButtonVariant.secondary,
              width: double.infinity,
              onPressed: () => _saveRecipeToUserMenu(recipe),
            ),
          ],
        ),
      ),
    );
  }
}
