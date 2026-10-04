import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/calculation_engine.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/panda_button.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../nutrition_guide/domain/recipe_model.dart';
import '../../nutrition_guide/presentation/ai_nutritionist_screen.dart';
import '../../profile/presentation/profile_controller.dart';
import '../domain/daily_entry_model.dart';

class DailyLoggerScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSaved;

  const DailyLoggerScreen({super.key, this.onSaved});

  @override
  ConsumerState<DailyLoggerScreen> createState() => _DailyLoggerScreenState();
}

class _DailyLoggerScreenState extends ConsumerState<DailyLoggerScreen> {
  final _weightController = TextEditingController();
  final _caloriesInController = TextEditingController(text: '0');
  final _caloriesOutController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  final Set<String> _consumedMealIds = {};
  bool _swimming = false;
  bool _planFollowed = true;
  String _selectedDinner = 'NONE';
  bool _isInitialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _weightController.dispose();
    _caloriesInController.dispose();
    _caloriesOutController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _prefillDataIfNeeded() {
    if (_isInitialized) return;

    final profile = ref.read(userProfileProvider).value;
    final entries = ref.read(dailyEntriesProvider).value ?? [];

    if (entries.isNotEmpty && entries.first.weight != null) {
      // Prefill with the most recent logged morning weight
      _weightController.text = entries.first.weight!.toStringAsFixed(1);
      if (entries.first.caloriesIn != null) {
        _caloriesInController.text = entries.first.caloriesIn!.toString();
      }
      _isInitialized = true;
    } else if (profile != null) {
      // First time logging: prefill with account starting weight
      _weightController.text = profile.profileStartWeight.toStringAsFixed(1);
      _isInitialized = true;
    }
  }

  void _toggleMealConsumption(MealRecipe recipe, List<MealRecipe> allRecipes) {
    final recipeKey = recipe.id.isNotEmpty ? recipe.id : (recipe.code ?? recipe.title);

    setState(() {
      if (_consumedMealIds.contains(recipeKey)) {
        _consumedMealIds.remove(recipeKey);
      } else {
        _consumedMealIds.add(recipeKey);
      }

      // Automatically sum calories of all checked meals
      int totalCalories = 0;
      String lastDinner = 'NONE';

      for (final r in allRecipes) {
        final key = r.id.isNotEmpty ? r.id : (r.code ?? r.title);
        if (_consumedMealIds.contains(key)) {
          totalCalories += r.calories;
          if (r.category == 'DINNER' || r.category == 'CUSTOM') {
            lastDinner = r.title;
          }
        }
      }

      _caloriesInController.text = totalCalories.toString();
      _selectedDinner = lastDinner;
    });
  }

  Future<void> _saveEntry() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final rawWeight = double.tryParse(_weightController.text);
    if (rawWeight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Te rugăm să introduci o greutate validă.'),
          backgroundColor: AppColors.rose,
        ),
      );
      return;
    }

    final roundedWeight = CalculationEngine.roundWeight(rawWeight);
    final calIn = int.tryParse(_caloriesInController.text) ?? 0;
    final calOut = int.tryParse(_caloriesOutController.text) ?? 0;
    final netCal = CalculationEngine.calculateNetCalories(caloriesIn: calIn, caloriesOut: calOut);

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);

      final entry = DailyEntry(
        id: '',
        userId: user.id,
        entryDate: todayDate,
        weight: roundedWeight,
        swimming: _swimming,
        planFollowed: _planFollowed,
        caloriesIn: calIn,
        caloriesOut: calOut,
        netCalories: netCal,
        selectedDinner: _selectedDinner,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      final repo = ref.read(dailyEntryRepositoryProvider);
      await repo.saveDailyEntry(entry);

      // Invalidate to refresh Dashboard, Missions & Charts
      ref.invalidate(dailyEntriesProvider);
      ref.invalidate(userProfileProvider);
      ref.invalidate(activeMissionProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cântărirea de ${roundedWeight.toStringAsFixed(1)} kg și $calIn kcal au fost salvate!'),
          backgroundColor: AppColors.emerald,
        ),
      );

      widget.onSaved?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Eroare la salvare: $e'),
          backgroundColor: AppColors.rose,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to profile and entries to prefill when loaded
    ref.listen(userProfileProvider, (_, __) => _prefillDataIfNeeded());
    ref.listen(dailyEntriesProvider, (_, __) => _prefillDataIfNeeded());
    _prefillDataIfNeeded();

    final profile = ref.watch(userProfileProvider).value;
    final activeMission = ref.watch(activeMissionProvider).value;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'LOG TODAY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: AppColors.emerald,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Morning Weigh-in & Habits',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),

              // 1. Morning Weight
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Morning Weight (0.1 kg Precision)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Icon(Icons.scale, color: AppColors.cyan, size: 20),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Weigh immediately upon waking after restroom visit.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d{1,3}(\.\d{0,1})?$')),
                        LengthLimitingTextInputFormatter(5),
                      ],
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        suffixText: 'kg',
                        suffixStyle: TextStyle(fontSize: 18, color: AppColors.textSecondary),
                        prefixIcon: Icon(Icons.monitor_weight_outlined, color: AppColors.emerald),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Mese Consumate din Planul Personal (Interactive Checklists)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mese Consumate Azi',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Bifează mesele mâncate pentru calcul automat de calorii',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                        if (profile != null && activeMission != null)
                          IconButton(
                            icon: const Icon(Icons.smart_toy_outlined, color: AppColors.emeraldLight),
                            tooltip: 'Discută cu Panda Coach AI',
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => AiNutritionistScreen(
                                    profile: profile,
                                    activeMission: activeMission,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ref.watch(allRecipesProvider).when(
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(color: AppColors.emerald),
                            ),
                          ),
                          error: (_, __) => const Text(
                            'Nu am putut încărca meniul.',
                            style: TextStyle(color: AppColors.rose, fontSize: 13),
                          ),
                          data: (recipes) {
                            if (recipes.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.glassBorder),
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      'Nu ai încă rețete salvate în meniul tău personal.',
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    if (profile != null && activeMission != null)
                                      PandaButton(
                                        label: '🤖 Cere Mese de la Panda AI',
                                        icon: Icons.auto_awesome,
                                        variant: PandaButtonVariant.secondary,
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) => AiNutritionistScreen(
                                                profile: profile,
                                                activeMission: activeMission,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              );
                            }

                            return Column(
                              children: recipes.map((recipe) {
                                final recipeKey = recipe.id.isNotEmpty ? recipe.id : (recipe.code ?? recipe.title);
                                final isConsumed = _consumedMealIds.contains(recipeKey);

                                return _buildMealCheckCard(
                                  recipe: recipe,
                                  isConsumed: isConsumed,
                                  onChanged: (_) => _toggleMealConsumption(recipe, recipes),
                                );
                              }).toList(),
                            );
                          },
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Caloric Intake & Burn
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Energy Balance (Calories)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Text('Calories In', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                  SizedBox(width: 4),
                                  Icon(Icons.auto_awesome, size: 12, color: AppColors.emeraldLight),
                                ],
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _caloriesInController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(5),
                                ],
                                decoration: const InputDecoration(suffixText: 'kcal'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Calories Out (Burned)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _caloriesOutController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(5),
                                ],
                                decoration: const InputDecoration(suffixText: 'kcal'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Activity & Adherence Flags
              GlassCard(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      thumbColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected) ? AppColors.cyan : null,
                      ),
                      title: const Text('Swimming Session', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Logged active pool workout', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      value: _swimming,
                      onChanged: (val) => setState(() => _swimming = val),
                    ),
                    const Divider(color: AppColors.surfaceElevated),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      thumbColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected) ? AppColors.emerald : null,
                      ),
                      title: const Text('Nutrition Plan Followed', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Weighed foods and raw proteins as prescribed', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      value: _planFollowed,
                      onChanged: (val) => setState(() => _planFollowed = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 5. Notes / Deviations
              GlassCard(
                child: TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Gym sets, recovery, or notes',
                    alignLabelWithHint: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              PandaButton(
                label: 'Save Daily Entry',
                icon: Icons.check_circle_outline,
                width: double.infinity,
                isLoading: _isSaving,
                onPressed: _saveEntry,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealCheckCard({
    required MealRecipe recipe,
    required bool isConsumed,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isConsumed ? AppColors.emerald.withValues(alpha: 0.12) : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isConsumed ? AppColors.emerald : AppColors.glassBorder,
          width: isConsumed ? 1.5 : 1.0,
        ),
      ),
      child: CheckboxListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        activeColor: AppColors.emerald,
        checkColor: Colors.white,
        value: isConsumed,
        onChanged: onChanged,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                recipe.category,
                style: const TextStyle(
                  color: AppColors.emeraldLight,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                recipe.title,
                style: TextStyle(
                  color: isConsumed ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: isConsumed ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                  decoration: isConsumed ? TextDecoration.lineThrough : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            '${recipe.calories} kcal · ${recipe.proteinG ?? 0}g P · ${recipe.carbsG ?? 0}g C',
            style: const TextStyle(color: AppColors.cyanLight, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
