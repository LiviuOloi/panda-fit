import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/activity_calories_calculator.dart';
import '../../../../core/utils/calculation_engine.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/panda_button.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../nutrition_guide/domain/recipe_model.dart';
import '../../nutrition_guide/presentation/ai_nutritionist_screen.dart';
import '../../nutrition_guide/presentation/barcode_scanner_dialog.dart';
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

  late DateTime _selectedDate;
  bool _planFollowed = true;
  final Set<String> _consumedMealIds = {};
  final List<LoggedActivity> _loggedActivities = [];
  bool _swimming = false;
  String _selectedDinner = 'NONE';
  bool _isInitialized = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _weightController.addListener(_onWeightChanged);
  }

  @override
  void dispose() {
    _weightController.removeListener(_onWeightChanged);
    _weightController.dispose();
    _caloriesInController.dispose();
    _caloriesOutController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onWeightChanged() {
    if (_loggedActivities.isNotEmpty) {
      _recalculateCaloriesOut();
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _prefillDataIfNeeded() {
    if (_isInitialized) return;
    _loadDateData(_selectedDate);
    _isInitialized = true;
  }

  void _loadDateData(DateTime targetDate) {
    final entries = ref.read(dailyEntriesProvider).value ?? [];
    final matching = entries.where((e) => _isSameDay(e.entryDate, targetDate)).toList();

    if (matching.isNotEmpty) {
      final entry = matching.first;
      _weightController.text = entry.weight?.toStringAsFixed(1) ?? '';
      _caloriesInController.text = (entry.caloriesIn ?? 0).toString();
      _caloriesOutController.text = (entry.caloriesOut ?? 0).toString();
      _planFollowed = entry.planFollowed;
      _swimming = entry.swimming;
      _selectedDinner = entry.selectedDinner ?? 'NONE';

      if (entry.notes != null && entry.notes!.trim().startsWith('{')) {
        try {
          final decoded = json.decode(entry.notes!) as Map<String, dynamic>;
          _consumedMealIds.clear();
          if (decoded['consumed_meal_ids'] != null) {
            final ids = (decoded['consumed_meal_ids'] as List<dynamic>).map((e) => e.toString()).toSet();
            _consumedMealIds.addAll(ids);
          }
          _loggedActivities.clear();
          if (decoded['activities'] != null) {
            for (final item in decoded['activities'] as List<dynamic>) {
              final m = item as Map<String, dynamic>;
              final typeStr = m['type'] as String? ?? 'weightlifting';
              final actType = PhysicalActivityType.values.firstWhere(
                (v) => v.name == typeStr,
                orElse: () => PhysicalActivityType.weightlifting,
              );
              _loggedActivities.add(
                LoggedActivity(
                  id: m['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
                  activityType: actType,
                  durationMinutes: (m['duration'] as num?)?.toInt() ?? 30,
                  customCalories: (m['custom_cal'] as num?)?.toInt(),
                  isDurationMode: m['is_duration'] as bool? ?? true,
                ),
              );
            }
          }
          _notesController.text = decoded['user_notes'] as String? ?? '';
        } catch (_) {
          _notesController.text = entry.notes ?? '';
        }
      } else {
        _notesController.text = entry.notes ?? '';
      }
    } else {
      final isToday = _isSameDay(targetDate, DateTime.now());
      if (isToday) {
        if (entries.isNotEmpty && entries.first.weight != null) {
          _weightController.text = entries.first.weight!.toStringAsFixed(1);
        } else {
          final profile = ref.read(userProfileProvider).value;
          _weightController.text = profile?.profileStartWeight.toStringAsFixed(1) ?? '';
        }
      } else {
        _weightController.text = '';
      }
      _caloriesInController.text = '0';
      _caloriesOutController.text = '0';
      _consumedMealIds.clear();
      _loggedActivities.clear();
      _notesController.clear();
      _planFollowed = true;
      _swimming = false;
      _selectedDinner = 'NONE';
    }
  }

  void _changeDate(DateTime newDate) {
    setState(() {
      _selectedDate = DateTime(newDate.year, newDate.month, newDate.day);
      _loadDateData(_selectedDate);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.emerald,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _changeDate(picked);
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

  void _addActivity() {
    setState(() {
      _loggedActivities.add(
        LoggedActivity(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          activityType: PhysicalActivityType.weightlifting,
          durationMinutes: 45,
          isDurationMode: true,
        ),
      );
      _recalculateCaloriesOut();
    });
  }

  void _removeActivity(String id) {
    setState(() {
      _loggedActivities.removeWhere((act) => act.id == id);
      _recalculateCaloriesOut();
    });
  }

  void _recalculateCaloriesOut() {
    final rawWeight = double.tryParse(_weightController.text);
    final profile = ref.read(userProfileProvider).value;
    final currentWeight = rawWeight ?? profile?.profileStartWeight ?? 80.0;

    int totalBurned = 0;
    bool hasSwimming = false;

    for (final act in _loggedActivities) {
      totalBurned += act.getCalories(currentWeight);
      if (act.activityType.isSwimming) {
        hasSwimming = true;
      }
    }

    setState(() {
      _swimming = hasSwimming;
      _caloriesOutController.text = totalBurned.toString();
    });
  }

  Future<void> _saveEntry() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final rawWeight = double.tryParse(_weightController.text);
    if (rawWeight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid numeric weight.'),
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
      final metadata = {
        'consumed_meal_ids': _consumedMealIds.toList(),
        'activities': _loggedActivities.map((a) => {
          'id': a.id,
          'type': a.activityType.name,
          'duration': a.durationMinutes,
          'custom_cal': a.customCalories,
          'is_duration': a.isDurationMode,
        },).toList(),
        'user_notes': _notesController.text.trim(),
      };
      final encodedNotes = json.encode(metadata);

      final entry = DailyEntry(
        id: '',
        userId: user.id,
        entryDate: _selectedDate,
        weight: roundedWeight,
        swimming: _swimming,
        planFollowed: _planFollowed,
        caloriesIn: calIn,
        caloriesOut: calOut,
        netCalories: netCal,
        selectedDinner: _selectedDinner,
        notes: encodedNotes,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      final repo = ref.read(dailyEntryRepositoryProvider);
      final existingEntries = ref.read(dailyEntriesProvider).value;
      await repo.saveDailyEntry(entry, existingEntries: existingEntries);

      // Invalidate to refresh Dashboard, Missions & Charts
      ref.invalidate(dailyEntriesProvider);
      ref.invalidate(userProfileProvider);
      ref.invalidate(activeMissionProvider);

      if (!mounted) return;

      final dateLabel = DateFormat('d MMM yyyy').format(_selectedDate);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Jurnal salvat ($dateLabel)! Greutate: ${roundedWeight.toStringAsFixed(1)} kg | In: $calIn kcal | Arse: $calOut kcal 🐼'),
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
    ref.listen(userProfileProvider, (_, __) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _prefillDataIfNeeded());
    });
    ref.listen(dailyEntriesProvider, (_, __) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _prefillDataIfNeeded());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillDataIfNeeded());

    final profile = ref.watch(userProfileProvider).value;
    final activeMission = ref.watch(activeMissionProvider).value;
    final rawWeight = double.tryParse(_weightController.text);
    final effectiveWeight = rawWeight ?? profile?.profileStartWeight ?? 80.0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = _isSameDay(_selectedDate, today);
    final isYesterday = _isSameDay(_selectedDate, today.subtract(const Duration(days: 1)));

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'DAILY LOG',
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
              const SizedBox(height: 16),

              // Date Navigator Bar
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: AppColors.emeraldLight, size: 22),
                      tooltip: 'Ziua anterioară',
                      onPressed: () => _changeDate(_selectedDate.subtract(const Duration(days: 1))),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.cyan),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  DateFormat('EEEE, d MMMM yyyy').format(_selectedDate),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? AppColors.emerald.withValues(alpha: 0.2)
                                      : (isYesterday ? AppColors.cyan.withValues(alpha: 0.2) : AppColors.surfaceElevated),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isToday ? 'ASTĂZI' : (isYesterday ? 'IERI' : 'ISTORIC'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isToday
                                        ? AppColors.emeraldLight
                                        : (isYesterday ? AppColors.cyanLight : AppColors.textMuted),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.chevron_right,
                        color: _selectedDate.isBefore(today) ? AppColors.emeraldLight : AppColors.textMuted,
                        size: 22,
                      ),
                      tooltip: 'Ziua următoare',
                      onPressed: _selectedDate.isBefore(today)
                          ? () => _changeDate(_selectedDate.add(const Duration(days: 1)))
                          : null,
                    ),
                  ],
                ),
              ),

              // 1. Morning Weight Card
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

              // 2. Daily Meals Consumed (Interactive Checklists)
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
                              'Daily Meals Consumed',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Check off meals to automatically accumulate calories in',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                        if (profile != null && activeMission != null)
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.qr_code_scanner, color: AppColors.amber),
                                tooltip: 'Scanează Cod de Bare Aliment',
                                onPressed: () {
                                  BarcodeScannerDialog.show(
                                    context,
                                    onConsultAi: (prompt) {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => AiNutritionistScreen(
                                            profile: profile,
                                            activeMission: activeMission,
                                            initialPrompt: prompt,
                                          ),
                                        ),
                                      );
                                    },
                                    onRecipeSaved: (recipe) {
                                      ref.invalidate(allRecipesProvider);
                                    },
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.smart_toy_outlined, color: AppColors.emeraldLight),
                                tooltip: 'Consult Panda Coach AI',
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
                            'Could not load meals menu.',
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
                                      'No meals saved in your personal menu yet.',
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    if (profile != null && activeMission != null)
                                      PandaButton(
                                        label: 'Generate Meals with Panda AI',
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

                            // Calculate live macro totals from consumed meals
                            int consumedKcal = 0;
                            double consumedProtein = 0;
                            double consumedCarbs = 0;
                            double consumedFat = 0;

                            for (final r in recipes) {
                              final recipeKey = r.id.isNotEmpty ? r.id : (r.code ?? r.title);
                              if (_consumedMealIds.contains(recipeKey)) {
                                consumedKcal += r.calories;
                                consumedProtein += (r.proteinG ?? 0);
                                consumedCarbs += (r.carbsG ?? 0);
                                consumedFat += (r.fatG ?? 0);
                              }
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_consumedMealIds.isNotEmpty) ...[
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildMacroPill('Calorii Mese', '$consumedKcal kcal', AppColors.emeraldLight),
                                        _buildMacroPill('Proteine', '${consumedProtein.toStringAsFixed(1)}g', AppColors.cyanLight),
                                        _buildMacroPill('Carbohidrați', '${consumedCarbs.toStringAsFixed(1)}g', AppColors.amber),
                                        _buildMacroPill('Grăsimi', '${consumedFat.toStringAsFixed(1)}g', AppColors.purple),
                                      ],
                                    ),
                                  ),
                                ],
                                Column(
                                  children: recipes.map((recipe) {
                                    final recipeKey = recipe.id.isNotEmpty ? recipe.id : (recipe.code ?? recipe.title);
                                    final isConsumed = _consumedMealIds.contains(recipeKey);

                                    return _buildMealCheckCard(
                                      recipe: recipe,
                                      isConsumed: isConsumed,
                                      onChanged: (_) => _toggleMealConsumption(recipe, recipes),
                                    );
                                  }).toList(),
                                ),
                              ],
                            );
                          },
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Daily Physical Activities
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Daily Physical Activities',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Log duration or calories to automatically accumulate calories out',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addActivity,
                          icon: const Icon(Icons.add_circle_outline, color: AppColors.cyan, size: 18),
                          label: const Text(
                            'Add',
                            style: TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_loggedActivities.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.glassBorder,
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.fitness_center_outlined, color: AppColors.textMuted, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'No workout logged today. Tap "Add" to select an activity.',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: _loggedActivities.map((activity) {
                          return _buildActivityCard(activity, effectiveWeight);
                        }).toList(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. Energy Balance (Calories & Net Progress)
              GlassCard(
                child: Builder(
                  builder: (context) {
                    final targetCal = profile?.dailyTargetCalories ?? 2300;
                    final calIn = int.tryParse(_caloriesInController.text) ?? 0;
                    final calOut = int.tryParse(_caloriesOutController.text) ?? 0;
                    final netCal = calIn - calOut;
                    final remainingCal = targetCal - netCal;
                    final progressRatio = (targetCal > 0) ? (netCal / targetCal).clamp(0.0, 1.0) : 0.0;
                    final isOverBudget = netCal > targetCal;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Energy Balance & Net Calories',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Balance Overview Banner
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isOverBudget
                                  ? AppColors.rose.withValues(alpha: 0.4)
                                  : AppColors.emerald.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Calorii Net', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                      Text(
                                        '$netCal kcal',
                                        style: TextStyle(
                                          color: isOverBudget ? AppColors.rose : AppColors.textPrimary,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        isOverBudget ? 'Excedent' : 'Rămase în buget',
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                      ),
                                      Text(
                                        isOverBudget ? '+${netCal - targetCal} kcal' : '$remainingCal kcal',
                                        style: TextStyle(
                                          color: isOverBudget ? AppColors.rose : AppColors.emeraldLight,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progressRatio,
                                  minHeight: 6,
                                  backgroundColor: AppColors.surfaceElevated,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isOverBudget ? AppColors.rose : AppColors.emerald,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Input fields for In and Out
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
                                    onChanged: (_) => setState(() {}),
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
                                  const Row(
                                    children: [
                                      Text('Calories Out (Burned)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                      SizedBox(width: 4),
                                      Icon(Icons.auto_awesome, size: 12, color: AppColors.cyanLight),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _caloriesOutController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(5),
                                    ],
                                    onChanged: (_) => setState(() {}),
                                    decoration: const InputDecoration(suffixText: 'kcal'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // 5. Habits, Adherence & Daily Notes
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Habits, Adherence & Notes',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Plan adherence selector
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => _planFollowed = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                              decoration: BoxDecoration(
                                color: _planFollowed
                                    ? AppColors.emerald.withValues(alpha: 0.2)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _planFollowed ? AppColors.emerald : AppColors.glassBorder,
                                  width: _planFollowed ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 16,
                                    color: _planFollowed ? AppColors.emeraldLight : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Plan Respectat',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _planFollowed ? FontWeight.bold : FontWeight.w500,
                                      color: _planFollowed ? AppColors.emeraldLight : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => _planFollowed = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                              decoration: BoxDecoration(
                                color: !_planFollowed
                                    ? AppColors.amber.withValues(alpha: 0.2)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: !_planFollowed ? AppColors.amber : AppColors.glassBorder,
                                  width: !_planFollowed ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 16,
                                    color: !_planFollowed ? AppColors.amber : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Abatere / Deviație',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: !_planFollowed ? FontWeight.bold : FontWeight.w500,
                                      color: !_planFollowed ? AppColors.amber : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Daily notes
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Note & Observații (opțional)',
                        hintText: 'Antrenament, greutăți, stare, energie, deviații de la plan...',
                        prefixIcon: Icon(Icons.notes_rounded, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              PandaButton(
                label: 'Salvează Jurnalul (${DateFormat('d MMM').format(_selectedDate)})',
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

  Widget _buildMacroPill(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
            '+${recipe.calories} kcal · ${recipe.proteinG ?? 0}g P · ${recipe.carbsG ?? 0}g C',
            style: const TextStyle(color: AppColors.cyanLight, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(LoggedActivity activity, double weightKg) {
    final estimatedBurn = activity.getCalories(weightKg);

    return Container(
      key: ValueKey(activity.id),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Activity Selector Tile & Delete
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _showActivityPicker(activity),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(activity.activityType.icon, color: AppColors.cyan, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activity.activityType.displayName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'MET: ${activity.activityType.pessimisticMet}',
                                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.rose, size: 18),
                visualDensity: VisualDensity.compact,
                tooltip: 'Remove',
                onPressed: () => _removeActivity(activity.id),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Mode Selector & Value Input
          Row(
            children: [
              // Segmented Duration vs Direct
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          activity.isDurationMode = true;
                          _recalculateCaloriesOut();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: activity.isDurationMode ? AppColors.cyan.withValues(alpha: 0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '⏱️ Duration',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: activity.isDurationMode ? FontWeight.bold : FontWeight.normal,
                            color: activity.isDurationMode ? AppColors.cyanLight : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          activity.isDurationMode = false;
                          _recalculateCaloriesOut();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: !activity.isDurationMode ? AppColors.emerald.withValues(alpha: 0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '🔥 Direct kcal',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: !activity.isDurationMode ? FontWeight.bold : FontWeight.normal,
                            color: !activity.isDurationMode ? AppColors.emeraldLight : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Value Input Field
              Expanded(
                child: activity.isDurationMode
                    ? TextFormField(
                        initialValue: activity.durationMinutes.toString(),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          suffixText: 'min',
                        ),
                        onChanged: (val) {
                          activity.durationMinutes = int.tryParse(val) ?? 0;
                          _recalculateCaloriesOut();
                        },
                      )
                    : TextFormField(
                        initialValue: activity.customCalories?.toString() ?? '',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          suffixText: 'kcal',
                          hintText: 'e.g. 350',
                        ),
                        onChanged: (val) {
                          activity.customCalories = int.tryParse(val);
                          _recalculateCaloriesOut();
                        },
                      ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 3: Live Burn Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                activity.isDurationMode
                    ? '⚡ Pessimistic estimate: ~$estimatedBurn kcal'
                    : '🔥 Direct burn logged: $estimatedBurn kcal',
                style: const TextStyle(
                  color: AppColors.cyanLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showActivityPicker(LoggedActivity activity) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.70,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Physical Activity',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: PhysicalActivityType.values.length,
                    separatorBuilder: (_, __) => const Divider(color: AppColors.glassBorder, height: 1),
                    itemBuilder: (context, idx) {
                      final type = PhysicalActivityType.values[idx];
                      final isSelected = activity.activityType == type;

                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.cyan.withValues(alpha: 0.25) : AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            type.icon,
                            color: isSelected ? AppColors.cyan : AppColors.textSecondary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          type.displayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? AppColors.cyanLight : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'Pessimistic MET: ${type.pessimisticMet}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: AppColors.cyan, size: 20)
                            : null,
                        onTap: () {
                          setState(() {
                            activity.activityType = type;
                            _recalculateCaloriesOut();
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
