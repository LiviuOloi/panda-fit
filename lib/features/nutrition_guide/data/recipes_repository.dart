import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/recipe_model.dart';

class RecipesRepository {
  final SupabaseClient? _client;
  static const _uuid = Uuid();
  static const _localCustomRecipesKey = 'panda_fit_custom_recipes_cache';

  RecipesRepository([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  Future<List<MealRecipe>> fetchAllRecipes(String? userId) async {
    final Map<String, MealRecipe> recipesMap = {};

    // 1. Load custom recipes from local storage (starts clean/empty for new users)
    try {
      final prefs = await SharedPreferences.getInstance();
      final localJson = prefs.getString(_localCustomRecipesKey);
      if (localJson != null) {
        final localList = json.decode(localJson) as List<dynamic>;
        for (final item in localList) {
          final recipe = MealRecipe.fromJson(item as Map<String, dynamic>);
          recipesMap[recipe.id] = recipe;
        }
      }
    } catch (e) {
      debugPrint('Failed to load local custom recipes: $e');
    }

    // 2. If connected to Supabase, query user's personal cloud recipes and merge
    if (_client != null && userId != null && userId.isNotEmpty) {
      try {
        final res = await _client
            .from('meal_recipes')
            .select()
            .eq('user_id', userId)
            .order('category', ascending: true);
        if (res.isNotEmpty) {
          for (final r in res) {
            final recipe = MealRecipe.fromJson(r);
            recipesMap[recipe.id] = recipe;
          }
        }
      } catch (e) {
        debugPrint('Supabase fetchAllRecipes note: $e');
      }
    }

    // Sort logically: BREAKFAST -> LUNCH -> DINNER -> SNACK -> CUSTOM
    final sorted = recipesMap.values.toList();
    const order = {'BREAKFAST': 1, 'LUNCH': 2, 'DINNER': 3, 'SNACK': 4, 'CUSTOM': 5};
    sorted.sort((a, b) {
      final orderA = order[a.category.toUpperCase()] ?? 99;
      final orderB = order[b.category.toUpperCase()] ?? 99;
      return orderA.compareTo(orderB);
    });

    return sorted;
  }

  Future<MealRecipe> createCustomRecipe(MealRecipe recipe) async {
    final assignedId = recipe.id.isNotEmpty ? recipe.id : _uuid.v4();
    final newRecipe = MealRecipe(
      id: assignedId,
      userId: recipe.userId,
      category: recipe.category,
      code: recipe.code,
      title: recipe.title,
      ingredients: recipe.ingredients,
      calories: recipe.calories,
      proteinG: recipe.proteinG,
      carbsG: recipe.carbsG,
      fatG: recipe.fatG,
      instructions: recipe.instructions,
    );

    // 1. Save to local storage
    await _saveToLocalCache(newRecipe);

    // 2. Try saving to Supabase
    if (_client != null && newRecipe.userId != null) {
      try {
        final payload = newRecipe.toJson();
        await _client.from('meal_recipes').insert(payload);
      } catch (e) {
        debugPrint('Supabase insert recipe note (cached locally): $e');
      }
    }

    return newRecipe;
  }

  Future<void> saveBatchMealPlan(List<MealRecipe> recipes, String? userId) async {
    for (final recipe in recipes) {
      final toSave = MealRecipe(
        id: recipe.id.isNotEmpty ? recipe.id : _uuid.v4(),
        userId: userId,
        category: recipe.category,
        code: recipe.code,
        title: recipe.title,
        ingredients: recipe.ingredients,
        calories: recipe.calories,
        proteinG: recipe.proteinG,
        carbsG: recipe.carbsG,
        fatG: recipe.fatG,
        instructions: recipe.instructions,
      );
      await _saveToLocalCache(toSave);
      if (_client != null && userId != null) {
        try {
          await _client.from('meal_recipes').insert(toSave.toJson());
        } catch (_) {}
      }
    }
  }

  Future<void> updateCustomRecipe(MealRecipe recipe) async {
    if (recipe.id.isEmpty) return;

    // 1. Update in local storage
    await _saveToLocalCache(recipe);

    // 2. Try updating in Supabase
    if (_client != null) {
      try {
        await _client
            .from('meal_recipes')
            .update(recipe.toJson())
            .eq('id', recipe.id);
      } catch (e) {
        debugPrint('Supabase update recipe note: $e');
      }
    }
  }

  Future<void> deleteCustomRecipe(String recipeId) async {
    // 1. Delete from local storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final localJson = prefs.getString(_localCustomRecipesKey);
      if (localJson != null) {
        final localList = json.decode(localJson) as List<dynamic>;
        final filtered = localList
            .where((item) => (item as Map<String, dynamic>)['id'] != recipeId)
            .toList();
        await prefs.setString(_localCustomRecipesKey, json.encode(filtered));
      }
    } catch (e) {
      debugPrint('Failed to delete recipe from local storage: $e');
    }

    // 2. Try deleting from Supabase
    if (_client != null) {
      try {
        await _client.from('meal_recipes').delete().eq('id', recipeId);
      } catch (e) {
        debugPrint('Supabase delete recipe note: $e');
      }
    }
  }

  Future<void> clearAllCustomRecipes(String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localCustomRecipesKey);
    } catch (e) {
      debugPrint('Failed to clear local custom recipes: $e');
    }

    if (_client != null && userId != null && userId.isNotEmpty) {
      try {
        await _client.from('meal_recipes').delete().eq('user_id', userId);
      } catch (e) {
        debugPrint('Supabase clear recipes note: $e');
      }
    }
  }

  Future<void> _saveToLocalCache(MealRecipe recipe) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localJson = prefs.getString(_localCustomRecipesKey);
      List<dynamic> list = [];
      if (localJson != null) {
        list = json.decode(localJson) as List<dynamic>;
      }

      // Remove existing if updating
      list.removeWhere((item) => (item as Map<String, dynamic>)['id'] == recipe.id);
      list.add(recipe.toJson());

      await prefs.setString(_localCustomRecipesKey, json.encode(list));
    } catch (e) {
      debugPrint('Failed to save recipe to local cache: $e');
    }
  }
}
