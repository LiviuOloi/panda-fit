import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/exercise_library.dart';
import '../../domain/exercise_model.dart';

class ExercisePickerDialog extends StatefulWidget {
  final ValueChanged<ExerciseInfo> onExerciseSelected;

  const ExercisePickerDialog({
    super.key,
    required this.onExerciseSelected,
  });

  static Future<ExerciseInfo?> show(BuildContext context) {
    return showDialog<ExerciseInfo>(
      context: context,
      builder: (context) => ExercisePickerDialog(
        onExerciseSelected: (exercise) => Navigator.pop(context, exercise),
      ),
    );
  }

  @override
  State<ExercisePickerDialog> createState() => _ExercisePickerDialogState();
}

class _ExercisePickerDialogState extends State<ExercisePickerDialog> {
  String _searchQuery = '';
  MuscleGroup? _selectedGroup;

  @override
  Widget build(BuildContext context) {
    final filtered = ExerciseLibrary.allExercises.where((ex) {
      if (_selectedGroup != null && ex.muscleGroup != _selectedGroup) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesRo = ex.nameRo.toLowerCase().contains(q);
        final matchesEn = ex.nameEn.toLowerCase().contains(q);
        final matchesEquip = ex.equipment.toLowerCase().contains(q);
        if (!matchesRo && !matchesEn && !matchesEquip) return false;
      }
      return true;
    }).toList();

    return Dialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.glassBorder),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.fitness_center, color: AppColors.emerald, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Alege Exercițiu',
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

              // Search field
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Caută exercițiu (ex: bench press, genuflexiuni, ramat)...',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.glassBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.glassBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.emerald),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Muscle Group Chips
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildFilterChip('Toate', null),
                    ...MuscleGroup.values.map(
                      (g) => _buildFilterChip(g.displayName, g),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.glassBorder, height: 1),
              const SizedBox(height: 8),

              // Exercise List
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'Nu am găsit exerciții care să corespundă căutării.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final ex = filtered[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.glassBorder),
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.emerald.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(ex.muscleGroup.icon, color: AppColors.emerald, size: 20),
                              ),
                              title: Text(
                                ex.nameRo,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${ex.nameEn} · ${ex.equipment}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.add_circle_outline,
                                color: AppColors.emerald,
                                size: 22,
                              ),
                              onTap: () => widget.onExerciseSelected(ex),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, MuscleGroup? group) {
    final isSelected = _selectedGroup == group;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedGroup = group),
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.emerald.withValues(alpha: 0.25),
        labelStyle: TextStyle(
          color: isSelected ? AppColors.emerald : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(
          color: isSelected ? AppColors.emerald : AppColors.glassBorder,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        showCheckmark: false,
      ),
    );
  }
}
