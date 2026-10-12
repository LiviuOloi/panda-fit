import 'recipe_model.dart';

class ScannedFoodProduct {
  final String barcode;
  final String name;
  final String? brand;
  final String? imageUrl;
  final int caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double sugarsPer100g;
  final double fatPer100g;
  final double saturatedFatPer100g;
  final double fiberPer100g;
  final String? nutriscoreGrade;
  final String? ingredientsText;
  final String? servingSize;

  const ScannedFoodProduct({
    required this.barcode,
    required this.name,
    this.brand,
    this.imageUrl,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    this.sugarsPer100g = 0.0,
    required this.fatPer100g,
    this.saturatedFatPer100g = 0.0,
    this.fiberPer100g = 0.0,
    this.nutriscoreGrade,
    this.ingredientsText,
    this.servingSize,
  });

  factory ScannedFoodProduct.fromOpenFoodFacts(String barcode, Map<String, dynamic> product) {
    final nutriments = (product['nutriments'] as Map<String, dynamic>?) ?? {};

    // Energy extraction: try energy-kcal_100g, else convert energy_100g (kJ) to kcal (/ 4.184)
    int kcal = 0;
    if (nutriments['energy-kcal_100g'] != null) {
      kcal = (nutriments['energy-kcal_100g'] as num).round();
    } else if (nutriments['energy-kcal'] != null) {
      kcal = (nutriments['energy-kcal'] as num).round();
    } else if (nutriments['energy_100g'] != null) {
      kcal = ((nutriments['energy_100g'] as num) / 4.184).round();
    }

    double toDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return ((val * 10).round() / 10).toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    final name = (product['product_name_ro'] as String?)?.trim().isNotEmpty == true
        ? (product['product_name_ro'] as String).trim()
        : (product['product_name'] as String?)?.trim().isNotEmpty == true
            ? (product['product_name'] as String).trim()
            : 'Produs fără nume ($barcode)';

    final brand = (product['brands'] as String?)?.trim();
    final imageUrl = (product['image_front_url'] as String?) ?? (product['image_url'] as String?);
    final nutriscore = (product['nutriscore_grade'] as String?)?.toUpperCase();
    final ingredients = (product['ingredients_text_ro'] as String?) ?? (product['ingredients_text'] as String?);
    final serving = (product['serving_size'] as String?) ?? (product['quantity'] as String?);

    return ScannedFoodProduct(
      barcode: barcode,
      name: name,
      brand: brand?.isNotEmpty == true ? brand : null,
      imageUrl: imageUrl?.isNotEmpty == true ? imageUrl : null,
      caloriesPer100g: kcal > 0 ? kcal : 0,
      proteinPer100g: toDouble(nutriments['proteins_100g']),
      carbsPer100g: toDouble(nutriments['carbohydrates_100g']),
      sugarsPer100g: toDouble(nutriments['sugars_100g']),
      fatPer100g: toDouble(nutriments['fat_100g']),
      saturatedFatPer100g: toDouble(nutriments['saturated-fat_100g']),
      fiberPer100g: toDouble(nutriments['fiber_100g']),
      nutriscoreGrade: nutriscore?.isNotEmpty == true ? nutriscore : null,
      ingredientsText: ingredients?.isNotEmpty == true ? ingredients : null,
      servingSize: serving?.isNotEmpty == true ? serving : null,
    );
  }

  int calculateCalories(double grams) {
    return ((caloriesPer100g * grams) / 100.0).round();
  }

  double calculateProtein(double grams) {
    return (((proteinPer100g * grams) / 100.0) * 10).round() / 10;
  }

  double calculateCarbs(double grams) {
    return (((carbsPer100g * grams) / 100.0) * 10).round() / 10;
  }

  double calculateSugars(double grams) {
    return (((sugarsPer100g * grams) / 100.0) * 10).round() / 10;
  }

  double calculateFat(double grams) {
    return (((fatPer100g * grams) / 100.0) * 10).round() / 10;
  }

  double calculateFiber(double grams) {
    return (((fiberPer100g * grams) / 100.0) * 10).round() / 10;
  }

  MealRecipe toMealRecipe({
    required double grams,
    String category = 'SNACK',
    String? userId,
  }) {
    final title = brand != null && brand!.isNotEmpty ? '$name ($brand)' : name;
    final portionGrams = '${grams.round()}g';

    return MealRecipe(
      id: '',
      userId: userId,
      category: category,
      title: title,
      ingredients: [
        RecipeIngredient(
          name: name,
          amount: portionGrams,
          state: 'cântărit exact',
        ),
      ],
      calories: calculateCalories(grams),
      proteinG: calculateProtein(grams),
      carbsG: calculateCarbs(grams),
      fatG: calculateFat(grams),
      instructions: 'Produs scanat oficial OpenFoodFacts ($barcode). Porție cântărită: $portionGrams.',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'barcode': barcode,
      'name': name,
      'brand': brand,
      'image_url': imageUrl,
      'calories_per_100g': caloriesPer100g,
      'protein_per_100g': proteinPer100g,
      'carbs_per_100g': carbsPer100g,
      'sugars_per_100g': sugarsPer100g,
      'fat_per_100g': fatPer100g,
      'saturated_fat_per_100g': saturatedFatPer100g,
      'fiber_per_100g': fiberPer100g,
      'nutriscore_grade': nutriscoreGrade,
      'ingredients_text': ingredientsText,
      'serving_size': servingSize,
    };
  }

  factory ScannedFoodProduct.fromJson(Map<String, dynamic> json) {
    return ScannedFoodProduct(
      barcode: json['barcode'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      imageUrl: json['image_url'] as String?,
      caloriesPer100g: (json['calories_per_100g'] as num).toInt(),
      proteinPer100g: (json['protein_per_100g'] as num).toDouble(),
      carbsPer100g: (json['carbs_per_100g'] as num).toDouble(),
      sugarsPer100g: (json['sugars_per_100g'] as num?)?.toDouble() ?? 0.0,
      fatPer100g: (json['fat_per_100g'] as num).toDouble(),
      saturatedFatPer100g: (json['saturated_fat_per_100g'] as num?)?.toDouble() ?? 0.0,
      fiberPer100g: (json['fiber_per_100g'] as num?)?.toDouble() ?? 0.0,
      nutriscoreGrade: json['nutriscore_grade'] as String?,
      ingredientsText: json['ingredients_text'] as String?,
      servingSize: json['serving_size'] as String?,
    );
  }
}
