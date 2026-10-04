import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/recipe_model.dart';

class RecipesRepository {
  final SupabaseClient? _client;

  RecipesRepository([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  Future<List<MealRecipe>> fetchAllRecipes(String? userId) async {
    if (_client != null) {
      try {
        var query = _client.from('meal_recipes').select();
        if (userId != null) {
          query = query.or('user_id.is.null,user_id.eq.$userId');
        } else {
          query = query.filter('user_id', 'is', 'null');
        }

        final res = await query.order('category', ascending: true);

        if (res.isNotEmpty) {
          return (res as List<dynamic>)
              .map((r) => MealRecipe.fromJson(r as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {
        // Fallback to local asset seed if offline or error
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

  Future<MealRecipe?> createCustomRecipe(MealRecipe recipe) async {
    if (_client == null) return null;
    final payload = recipe.toJson();
    final res = await _client.from('meal_recipes').insert(payload).select().single();
    return MealRecipe.fromJson(res);
  }

  Future<void> updateCustomRecipe(MealRecipe recipe) async {
    if (_client == null || recipe.id.isEmpty) return;
    await _client
        .from('meal_recipes')
        .update(recipe.toJson())
        .eq('id', recipe.id);
  }

  Future<void> deleteCustomRecipe(String recipeId) async {
    if (_client == null) return;
    await _client.from('meal_recipes').delete().eq('id', recipeId);
  }
}
