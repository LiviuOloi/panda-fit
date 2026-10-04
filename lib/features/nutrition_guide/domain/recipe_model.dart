class RecipeIngredient {
  final String name;
  final String amount;
  final String state; // raw, frozen/raw, dry/uncooked, measured, ready

  const RecipeIngredient({
    required this.name,
    required this.amount,
    required this.state,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      name: json['name'] as String,
      amount: json['amount'] as String,
      state: json['state'] as String? ?? 'raw',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'state': state,
    };
  }
}

class MealRecipe {
  final String id;
  final String? userId; // null for system templates, set for personal recipes
  final String category; // 'BREAKFAST', 'SNACK', 'DINNER', 'CUSTOM'
  final String? code;
  final String title;
  final List<RecipeIngredient> ingredients;
  final int calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final String? instructions;

  const MealRecipe({
    required this.id,
    this.userId,
    required this.category,
    this.code,
    required this.title,
    required this.ingredients,
    required this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.instructions,
  });

  factory MealRecipe.fromJson(Map<String, dynamic> json) {
    final rawIngredients = json['ingredients'] as List<dynamic>? ?? [];
    return MealRecipe(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String?,
      category: json['category'] as String? ?? 'CUSTOM',
      code: json['code'] as String?,
      title: json['title'] as String? ?? 'Custom Meal',
      ingredients: rawIngredients
          .map((i) => RecipeIngredient.fromJson(i as Map<String, dynamic>))
          .toList(),
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      proteinG: (json['protein_g'] as num?)?.toDouble(),
      carbsG: (json['carbs_g'] as num?)?.toDouble(),
      fatG: (json['fat_g'] as num?)?.toDouble(),
      instructions: json['instructions'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'category': category,
      'title': title,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'calories': calories,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'instructions': instructions,
    };
    if (id.isNotEmpty) map['id'] = id;
    if (userId != null) map['user_id'] = userId;
    if (code != null) map['code'] = code;
    return map;
  }
}
