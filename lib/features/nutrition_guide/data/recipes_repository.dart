import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/recipe_model.dart';

class RecipesRepository {
  final SupabaseClient? _client;

  RecipesRepository([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  Future<List<MealRecipe>> fetchRecipes() async {
    if (_client != null) {
      try {
        final res = await _client
            .from('meal_recipes')
            .select()
            .order('category', ascending: true);

        if (res.isNotEmpty) {
          return (res as List<dynamic>)
              .map((r) => MealRecipe.fromJson(r as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {
        // Fallback to local asset seed if offline or table empty
      }
    }

    // Fallback: Read from local JSON seed
    try {
      final jsonString = await rootBundle.loadString('assets/recipes/seed_recipes.json');
      final list = json.decode(jsonString) as List<dynamic>;
      return list.map((r) => MealRecipe.fromJson(r as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}
