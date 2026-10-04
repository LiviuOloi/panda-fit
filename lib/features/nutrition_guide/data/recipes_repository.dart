import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

    // 1. Load system default seed recipes from asset
    try {
      final jsonString = await rootBundle.loadString('assets/recipes/seed_recipes.json');
      final list = json.decode(jsonString) as List<dynamic>;
      for (final r in list) {
        final recipe = MealRecipe.fromJson(r as Map<String, dynamic>);
        recipesMap[recipe.id.isNotEmpty ? recipe.id : recipe.title] = recipe;
      }
    } catch (e) {
      debugPrint('Failed to load asset recipes: $e');
    }

    // 2. Load custom recipes from local storage
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

    // 3. If connected to Supabase, query cloud recipes and merge
    if (_client != null) {
      try {
        var query = _client.from('meal_recipes').select();
        if (userId != null && userId.isNotEmpty) {
          query = query.or('user_id.is.null,user_id.eq.$userId');
        }

        final res = await query.order('category', ascending: true);
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

    return recipesMap.values.toList();
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
    if (_client != null) {
      try {
        final payload = newRecipe.toJson();
        await _client.from('meal_recipes').insert(payload);
      } catch (e) {
        debugPrint('Supabase insert recipe note (cached locally): $e');
      }
    }

    return newRecipe;
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
