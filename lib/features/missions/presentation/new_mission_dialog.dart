import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/calculation_engine.dart';
import '../../../../core/widgets/panda_button.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../profile/presentation/profile_controller.dart';
import '../domain/mission_model.dart';

class NewMissionDialog extends ConsumerStatefulWidget {
  final double currentWeight;
  final Mission? previousMission;
  final bool isPreviousAccomplished;

  const NewMissionDialog({
    super.key,
    required this.currentWeight,
    this.previousMission,
    this.isPreviousAccomplished = false,
  });

  @override
  ConsumerState<NewMissionDialog> createState() => _NewMissionDialogState();
}

class _NewMissionDialogState extends ConsumerState<NewMissionDialog> {
  late MissionType _selectedType;
  late final TextEditingController _startWeightController;
  late final TextEditingController _targetWeightController;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedType = MissionType.cutting;
    _startWeightController = TextEditingController(
      text: widget.currentWeight.toStringAsFixed(1),
    );
    final defaultTarget = widget.currentWeight > 5 ? (widget.currentWeight - 5.0) : 70.0;
    _targetWeightController = TextEditingController(
      text: defaultTarget.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _startWeightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  void _onTypeChanged(MissionType type) {
    setState(() {
      _selectedType = type;
      _errorMessage = null;
      final start = double.tryParse(_startWeightController.text) ?? widget.currentWeight;
      if (type == MissionType.cutting) {
        _targetWeightController.text = (start - 5.0).clamp(30.0, start - 0.1).toStringAsFixed(1);
      } else {
        _targetWeightController.text = (start + 5.0).toStringAsFixed(1);
      }
    });
  }

  Future<void> _submit() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final startWeight = double.tryParse(_startWeightController.text);
    final targetWeight = double.tryParse(_targetWeightController.text);

    if (startWeight == null || startWeight < 30 || startWeight > 350) {
      setState(() => _errorMessage = 'Please enter a valid start weight (30-350 kg).');
      return;
    }

    if (targetWeight == null || targetWeight < 30 || targetWeight > 350) {
      setState(() => _errorMessage = 'Please enter a valid target weight (30-350 kg).');
      return;
    }

    final roundedStart = CalculationEngine.roundWeight(startWeight);
    final roundedTarget = CalculationEngine.roundWeight(targetWeight);

    if (_selectedType == MissionType.cutting && roundedTarget >= roundedStart) {
      setState(() => _errorMessage = 'For Cutting, target weight must be strictly less than start weight ($roundedStart kg).');
      return;
    }

    if (_selectedType == MissionType.bulking && roundedTarget <= roundedStart) {
      setState(() => _errorMessage = 'For Bulking, target weight must be strictly greater than start weight ($roundedStart kg).');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(missionsRepositoryProvider);
      await repo.startNewMission(
        userId: user.id,
        missionType: _selectedType,
        startWeight: roundedStart,
        targetWeight: roundedTarget,
        previousActiveMissionId: widget.previousMission?.id,
        isPreviousAccomplished: widget.isPreviousAccomplished,
      );

      ref.invalidate(activeMissionProvider);

      if (!mounted) return;
      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 New ${_selectedType.name.toUpperCase()} mission active! Target: ${roundedTarget.toStringAsFixed(1)} kg'),
          backgroundColor: AppColors.emerald,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error creating mission: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.glassBorder),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.flag, color: AppColors.emerald, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Configure Next Mission',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (widget.isPreviousAccomplished)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.emerald.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: [
                    Text('🏆', style: TextStyle(fontSize: 22)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Congratulations! You successfully surpassed your previous milestone. Time to set your next goal!',
                        style: TextStyle(color: AppColors.emeraldLight, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            const Text(
              'Select Phase Type',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _onTypeChanged(MissionType.cutting),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedType == MissionType.cutting
                            ? AppColors.emerald.withValues(alpha: 0.2)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectedType == MissionType.cutting ? AppColors.emerald : AppColors.glassBorder,
                          width: _selectedType == MissionType.cutting ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text('✂️', style: TextStyle(fontSize: 20)),
                          const SizedBox(height: 4),
                          Text(
                            'Cutting (Fat Loss)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _selectedType == MissionType.cutting ? AppColors.emeraldLight : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _onTypeChanged(MissionType.bulking),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedType == MissionType.bulking
                            ? AppColors.cyan.withValues(alpha: 0.2)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectedType == MissionType.bulking ? AppColors.cyan : AppColors.glassBorder,
                          width: _selectedType == MissionType.bulking ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text('🦁', style: TextStyle(fontSize: 20)),
                          const SizedBox(height: 4),
                          Text(
                            'Bulking (Muscle)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _selectedType == MissionType.bulking ? AppColors.cyanLight : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Start Weight Field
            const Text(
              'Phase Start Weight',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _startWeightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d{1,3}(\.\d{0,1})?$')),
                LengthLimitingTextInputFormatter(5),
              ],
              decoration: const InputDecoration(
                suffixText: 'kg',
                prefixIcon: Icon(Icons.fitness_center, color: AppColors.cyan, size: 18),
              ),
            ),
            const SizedBox(height: 16),

            // Target Weight Field
            Text(
              _selectedType == MissionType.cutting ? 'Target Weight (Strictly < Start)' : 'Target Weight (Strictly > Start)',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _targetWeightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d{1,3}(\.\d{0,1})?$')),
                LengthLimitingTextInputFormatter(5),
              ],
              decoration: InputDecoration(
                suffixText: 'kg',
                prefixIcon: Icon(
                  _selectedType == MissionType.cutting ? Icons.arrow_downward : Icons.arrow_upward,
                  color: _selectedType == MissionType.cutting ? AppColors.emerald : AppColors.cyan,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.rose, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),

            // Submit Button
            PandaButton(
              label: '🚀 Launch Next Mission',
              icon: Icons.rocket_launch,
              width: double.infinity,
              isLoading: _isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
