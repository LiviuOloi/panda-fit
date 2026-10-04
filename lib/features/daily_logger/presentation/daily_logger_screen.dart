import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/calculation_engine.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/panda_button.dart';
import '../../auth/presentation/auth_controller.dart';
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
  final _caloriesInController = TextEditingController(text: '2300');
  final _caloriesOutController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  bool _swimming = false;
  bool _planFollowed = true;
  String _selectedDinner = 'CUSTOM';
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
      _caloriesInController.text = profile.dailyTargetCalories.toString();
      _isInitialized = true;
    }
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
    final calIn = int.tryParse(_caloriesInController.text) ?? 2300;
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
          content: Text('Cântărirea de ${roundedWeight.toStringAsFixed(1)} kg a fost salvată cu succes!'),
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

              // 2. Predefined & Personal Dinner Selector
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Opțiune Cină / Masă',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Alege o opțiune din meniul tău personal sau masă custom',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    ref.watch(allRecipesProvider).when(
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(color: AppColors.emerald),
                            ),
                          ),
                          error: (_, __) => _buildDinnerChip('CUSTOM', 'Cină Custom / În afara meniului'),
                          data: (recipes) {
                            final dinnerOptions = recipes.where((r) => r.category == 'DINNER' || r.category == 'CUSTOM').toList();

                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ...dinnerOptions.map(
                                  (r) => _buildDinnerChip(
                                    r.id.isNotEmpty ? r.id : (r.code ?? r.title),
                                    r.title,
                                  ),
                                ),
                                _buildDinnerChip('CUSTOM', 'Cină Custom (În afara meniului)'),
                              ],
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
                              const Text('Calories In', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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

  Widget _buildDinnerChip(String code, String label) {
    final isSelected = _selectedDinner == code;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedDinner = code),
      selectedColor: AppColors.emerald.withValues(alpha: 0.25),
      backgroundColor: AppColors.surfaceElevated,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.emeraldLight : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.emerald : Colors.transparent,
      ),
    );
  }
}
