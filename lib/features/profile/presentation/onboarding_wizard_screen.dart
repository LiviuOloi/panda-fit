import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/calculation_engine.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/panda_button.dart';
import '../../missions/domain/mission_model.dart';
import 'profile_controller.dart';

class OnboardingWizardScreen extends ConsumerStatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  ConsumerState<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends ConsumerState<OnboardingWizardScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // Step 1: Personal Info
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String _sex = 'MALE';

  // Step 2: Biometrics & Start Weight
  DateTime _birthDate = DateTime(1995, 1, 1);
  final _heightController = TextEditingController(text: '180');
  final _startWeightController = TextEditingController(text: '95.0');
  final _targetCaloriesController = TextEditingController(text: '2300');

  // Step 3: Initial Mission
  MissionType _missionType = MissionType.cutting;
  final _missionTargetWeightController = TextEditingController(text: '88.0');

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _heightController.dispose();
    _startWeightController.dispose();
    _targetCaloriesController.dispose();
    _missionTargetWeightController.dispose();
    super.dispose();
  }

  int get _calculatedAge => CalculationEngine.calculateAge(_birthDate);

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.emerald,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_usernameController.text.trim().isEmpty ||
          _firstNameController.text.trim().isEmpty ||
          _lastNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all identity fields.'), backgroundColor: AppColors.rose),
        );
        return;
      }
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      final h = double.tryParse(_heightController.text);
      final w = double.tryParse(_startWeightController.text);
      if (h == null || h < 50 || h > 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid height (50 - 300 cm).'), backgroundColor: AppColors.rose),
        );
        return;
      }
      if (w == null || w < 20 || w > 500) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid start weight (20 - 500 kg).'), backgroundColor: AppColors.rose),
        );
        return;
      }

      // Default initial target suggestion
      final roundedW = CalculationEngine.roundWeight(w);
      _startWeightController.text = roundedW.toStringAsFixed(1);
      if (_missionType == MissionType.cutting) {
        _missionTargetWeightController.text = (roundedW - 5.0).toStringAsFixed(1);
      } else {
        _missionTargetWeightController.text = (roundedW + 5.0).toStringAsFixed(1);
      }

      setState(() => _currentStep = 2);
    }
  }

  Future<void> _submitOnboarding() async {
    final startW = double.tryParse(_startWeightController.text);
    final targetW = double.tryParse(_missionTargetWeightController.text);
    final height = double.tryParse(_heightController.text) ?? 180.0;
    final calories = int.tryParse(_targetCaloriesController.text) ?? 2300;

    if (startW == null || targetW == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid numeric weights.'), backgroundColor: AppColors.rose),
      );
      return;
    }

    final roundedStart = CalculationEngine.roundWeight(startW);
    final roundedTarget = CalculationEngine.roundWeight(targetW);

    // Strict Domain Invariant Validation (AGENTS.md Section 4.3)
    if (_missionType == MissionType.cutting && roundedTarget >= roundedStart) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cutting invariant violation: Target weight must be strictly lower than starting weight.'),
          backgroundColor: AppColors.rose,
        ),
      );
      return;
    }

    if (_missionType == MissionType.bulking && roundedTarget <= roundedStart) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bulking invariant violation: Target weight must be strictly higher than starting weight.'),
          backgroundColor: AppColors.rose,
        ),
      );
      return;
    }

    final controller = ref.read(profileControllerProvider.notifier);
    final success = await controller.completeOnboarding(
      username: _usernameController.text,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      sex: _sex,
      birthDate: _birthDate,
      heightCm: height,
      profileStartWeight: roundedStart,
      dailyTargetCalories: calories,
      firstMissionType: _missionType,
      firstTargetWeight: roundedTarget,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile and First Mission initialized successfully! Welcome to PandaFit.'),
          backgroundColor: AppColors.emerald,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save profile. Please check connection.'),
          backgroundColor: AppColors.rose,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.emerald.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'STEP ${_currentStep + 1} OF 3',
                            style: const TextStyle(
                              color: AppColors.emeraldLight,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentStep == 0
                          ? 'Profile & Identity'
                          : _currentStep == 1
                              ? 'Biometrics & Starting Weight'
                              : 'Set Your First Mission',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _currentStep == 0
                          ? 'Enter your name and username to personalize your PandaFit journey.'
                          : _currentStep == 1
                              ? 'Record initial baselines. Starting weight becomes locked once daily logging begins.'
                              : 'Select your target phase (Cut or Bulk) with rigorous threshold tracking.',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    // Step Content
                    if (_currentStep == 0) _buildStep1(),
                    if (_currentStep == 1) _buildStep2(),
                    if (_currentStep == 2) _buildStep3(),

                    const SizedBox(height: 24),

                    // Navigation Buttons
                    Row(
                      children: [
                        if (_currentStep > 0) ...[
                          Expanded(
                            child: PandaButton(
                              label: 'Back',
                              variant: PandaButtonVariant.secondary,
                              onPressed: () => setState(() => _currentStep--),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          flex: 2,
                          child: PandaButton(
                            label: _currentStep == 2 ? 'Launch PandaFit Engine' : 'Continue',
                            icon: _currentStep == 2 ? Icons.rocket_launch : Icons.arrow_forward,
                            isLoading: profileState.isLoading,
                            onPressed: _currentStep == 2 ? _submitOnboarding : _nextStep,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.alternate_email, color: AppColors.textMuted, size: 20),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(labelText: 'First Name'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(labelText: 'Last Name'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Sex / Biological Profile', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildSexOption('MALE', 'Male'),
              const SizedBox(width: 8),
              _buildSexOption('FEMALE', 'Female'),
              const SizedBox(width: 8),
              _buildSexOption('OTHER', 'Other'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Birth Date with Dynamic Age
          InkWell(
            onTap: _pickBirthDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Date of Birth', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd MMMM yyyy').format(_birthDate),
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 15),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_calculatedAge yrs',
                      style: const TextStyle(color: AppColors.emeraldLight, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Height & Daily Calories
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _heightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Height',
                    suffixText: 'cm',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _targetCaloriesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Daily Calories',
                    suffixText: 'kcal',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Starting Weight
          const Text(
            'Starting Morning Weight (0.1 kg Precision)',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Lock Rule: Strictly immutable once daily weigh-in logs exist.',
            style: TextStyle(color: AppColors.amber, fontSize: 11),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _startWeightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            decoration: const InputDecoration(
              suffixText: 'kg',
              prefixIcon: Icon(Icons.scale, color: AppColors.emerald),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Mission Focus', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMissionTypeOption(
                  type: MissionType.cutting,
                  title: 'Cutting (Fat Loss)',
                  desc: 'Target < Start weight',
                  icon: Icons.trending_down,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMissionTypeOption(
                  type: MissionType.bulking,
                  title: 'Bulking (Muscle)',
                  desc: 'Target > Start weight',
                  icon: Icons.trending_up,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Target Weight
          const Text(
            'Mission Target Weight',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            _missionType == MissionType.cutting
                ? 'Strict Inequality: Accomplished only at < Target Weight (Tying is active).'
                : 'Strict Inequality: Accomplished only at > Target Weight (Tying is active).',
            style: const TextStyle(color: AppColors.cyanLight, fontSize: 11),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _missionTargetWeightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            decoration: const InputDecoration(
              suffixText: 'kg',
              prefixIcon: Icon(Icons.flag, color: AppColors.cyan),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSexOption(String value, String label) {
    final isSelected = _sex == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _sex = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.emerald.withValues(alpha: 0.2) : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? AppColors.emerald : AppColors.glassBorder),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.emeraldLight : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMissionTypeOption({
    required MissionType type,
    required String title,
    required String desc,
    required IconData icon,
  }) {
    final isSelected = _missionType == type;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _missionType = type;
          final startW = double.tryParse(_startWeightController.text) ?? 95.0;
          if (type == MissionType.cutting) {
            _missionTargetWeightController.text = (startW - 5.0).toStringAsFixed(1);
          } else {
            _missionTargetWeightController.text = (startW + 5.0).toStringAsFixed(1);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.emerald.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.emerald : AppColors.glassBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppColors.emerald : AppColors.textMuted, size: 28),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? AppColors.textPrimary : AppColors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(desc, style: const TextStyle(color: AppColors.textMuted, fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
