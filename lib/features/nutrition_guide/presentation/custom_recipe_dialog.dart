import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/panda_button.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/recipe_model.dart';
import 'ai_nutritionist_screen.dart';

class CustomRecipeDialog extends ConsumerStatefulWidget {
  final MealRecipe? existingRecipe;

  const CustomRecipeDialog({super.key, this.existingRecipe});

  @override
  ConsumerState<CustomRecipeDialog> createState() => _CustomRecipeDialogState();
}

class _CustomRecipeDialogState extends ConsumerState<CustomRecipeDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _caloriesController;
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _fatController;
  late TextEditingController _instructionsController;

  String _category = 'DINNER';
  final List<RecipeIngredient> _ingredients = [];

  final _ingredientNameController = TextEditingController();
  final _ingredientAmountController = TextEditingController();
  String _ingredientState = 'raw';

  @override
  void initState() {
    super.initState();
    final r = widget.existingRecipe;
    _titleController = TextEditingController(text: r?.title ?? '');
    _caloriesController = TextEditingController(text: r != null ? '${r.calories}' : '600');
    _proteinController = TextEditingController(text: r?.proteinG != null ? '${r!.proteinG}' : '45');
    _carbsController = TextEditingController(text: r?.carbsG != null ? '${r!.carbsG}' : '50');
    _fatController = TextEditingController(text: r?.fatG != null ? '${r!.fatG}' : '15');
    _instructionsController = TextEditingController(text: r?.instructions ?? '');
    _category = r?.category ?? 'DINNER';

    if (r != null) {
      _ingredients.addAll(r.ingredients);
    } else {
      _ingredients.add(const RecipeIngredient(name: 'Chicken Breast', amount: '220g', state: 'raw'));
      _ingredients.add(const RecipeIngredient(name: 'Basmati / Panzani Rice', amount: '100g', state: 'dry/uncooked'));
      _ingredients.add(const RecipeIngredient(name: 'Mixed Low-GI Veggies', amount: '250g', state: 'frozen/raw'));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _instructionsController.dispose();
    _ingredientNameController.dispose();
    _ingredientAmountController.dispose();
    super.dispose();
  }

  void _addIngredient() {
    if (_ingredientNameController.text.trim().isEmpty || _ingredientAmountController.text.trim().isEmpty) return;
    setState(() {
      _ingredients.add(
        RecipeIngredient(
          name: _ingredientNameController.text.trim(),
          amount: _ingredientAmountController.text.trim(),
          state: _ingredientState,
        ),
      );
      _ingredientNameController.clear();
      _ingredientAmountController.clear();
    });
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one ingredient.'), backgroundColor: AppColors.rose),
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final recipe = MealRecipe(
      id: widget.existingRecipe?.id ?? '',
      userId: user.id,
      category: _category,
      title: _titleController.text.trim(),
      ingredients: _ingredients,
      calories: int.tryParse(_caloriesController.text) ?? 0,
      proteinG: double.tryParse(_proteinController.text),
      carbsG: double.tryParse(_carbsController.text),
      fatG: double.tryParse(_fatController.text),
      instructions: _instructionsController.text.trim(),
    );

    final repo = ref.read(recipesRepositoryProvider);
    if (widget.existingRecipe != null) {
      await repo.updateCustomRecipe(recipe);
    } else {
      await repo.createCustomRecipe(recipe);
    }

    ref.invalidate(allRecipesProvider);

    if (!mounted) return;
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Recipe "${recipe.title}" saved successfully!'),
        backgroundColor: AppColors.emerald,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.glassBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.existingRecipe == null ? 'Add Custom Meal' : 'Edit Meal Recipe',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textMuted),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title & Category
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Recipe Title (e.g. Salmon & Low-GI Veggies)'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Please enter recipe title' : null,
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    dropdownColor: AppColors.surfaceElevated,
                    decoration: const InputDecoration(labelText: 'Meal Category'),
                    items: const [
                      DropdownMenuItem(value: 'BREAKFAST', child: Text('Breakfast')),
                      DropdownMenuItem(value: 'SNACK', child: Text('Snack / Lunch')),
                      DropdownMenuItem(value: 'DINNER', child: Text('Dinner')),
                      DropdownMenuItem(value: 'CUSTOM', child: Text('Custom Option')),
                    ],
                    onChanged: (v) => setState(() => _category = v ?? 'DINNER'),
                  ),
                  const SizedBox(height: 16),

                  // Macros
                  const Text('Nutrition & Energy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _caloriesController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Calories (kcal)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _proteinController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Protein (g)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _carbsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Carbs (g)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _fatController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Fat (g)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Ingredients List
                  const Text('Ingredients & Weighing State', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  ..._ingredients.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final ing = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${ing.name} — ${ing.amount} (${ing.state})',
                              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.rose),
                            onPressed: () => setState(() => _ingredients.removeAt(idx)),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 8),
                  // Add Ingredient inputs
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _ingredientNameController,
                          decoration: const InputDecoration(hintText: 'e.g. Lean Beef', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _ingredientAmountController,
                          decoration: const InputDecoration(hintText: '200g', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 6),
                      DropdownButton<String>(
                        value: _ingredientState,
                        dropdownColor: AppColors.surfaceElevated,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'raw', child: Text('raw')),
                          DropdownMenuItem(value: 'dry/uncooked', child: Text('dry')),
                          DropdownMenuItem(value: 'frozen/raw', child: Text('frozen')),
                          DropdownMenuItem(value: 'measured', child: Text('measured')),
                        ],
                        onChanged: (v) => setState(() => _ingredientState = v ?? 'raw'),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: AppColors.emerald),
                        onPressed: _addIngredient,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Save Button
                  PandaButton(
                    label: widget.existingRecipe == null ? 'Save Recipe' : 'Update Recipe',
                    icon: Icons.check,
                    onPressed: _saveRecipe,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
