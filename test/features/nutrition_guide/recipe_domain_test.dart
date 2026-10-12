import 'package:flutter_test/flutter_test.dart';
import 'package:panda_fit/features/missions/domain/mission_model.dart';
import 'package:panda_fit/features/nutrition_guide/data/ai_nutrition_service.dart';
import 'package:panda_fit/features/nutrition_guide/domain/recipe_model.dart';
import 'package:panda_fit/features/profile/domain/profile_model.dart';

void main() {
  group('Recipe Domain & AI Nutritionist Unit Tests', () {
    test('MealRecipe JSON serialization with user_id and weighed states', () {
      const recipe = MealRecipe(
        id: 'rec-123',
        userId: 'user-456',
        category: 'DINNER',
        title: 'Somon Sălbatic & Orez Brun',
        calories: 620,
        proteinG: 48.0,
        carbsG: 55.0,
        fatG: 18.0,
        instructions: 'Gătește somonul la cuptor fără ulei.',
        ingredients: [
          RecipeIngredient(name: 'File Somon', amount: '220g', state: 'raw'),
          RecipeIngredient(name: 'Orez Brun', amount: '90g', state: 'dry/uncooked'),
          RecipeIngredient(name: 'Sparanghel', amount: '200g', state: 'frozen/raw'),
        ],
      );

      final json = recipe.toJson();
      expect(json['user_id'], 'user-456');
      expect(json['title'], 'Somon Sălbatic & Orez Brun');
      expect((json['ingredients'] as List<dynamic>).length, 3);

      final reconstructed = MealRecipe.fromJson(json);
      expect(reconstructed.id, 'rec-123');
      expect(reconstructed.userId, 'user-456');
      expect(reconstructed.proteinG, 48.0);
      expect(reconstructed.ingredients.first.state, 'raw');
    });

    test('AI Nutrition Service generates tailored meals matching Cutting deficit', () async {
      final aiService = AiNutritionService();
      final profile = UserProfile(
        id: 'test-u',
        username: 'liviu',
        firstName: 'Liviu',
        lastName: 'Oloi',
        sex: 'MALE',
        birthDate: DateTime(1994, 6, 15),
        heightCm: 182.0,
        profileStartWeight: 98.4,
        dailyTargetCalories: 2300,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final cuttingMission = Mission(
        id: 'm-1',
        userId: 'test-u',
        missionType: MissionType.cutting,
        missionStartWeight: 98.4,
        targetWeight: 90.0,
        startedAt: DateTime(2026, 10, 1),
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );

      final meals = await aiService.generateCustomMealPlan(
        profile: profile,
        activeMission: cuttingMission,
        userPreferences: 'Fără carne de porc, mai mult pește și legume',
      );

      expect(meals.length, 4);
      // Verify raw weighing states are maintained
      final allIngredients = meals.expand((m) => m.ingredients).toList();
      expect(allIngredients.any((i) => i.state.contains('raw') || i.state.contains('dry')), isTrue);
    });

    test('isQuickOrSingleMealQuery correctly identifies single meal requests vs full day plans', () {
      expect(AiNutritionService.isQuickOrSingleMealQuery('O recomandare rapida de masa'), isTrue);
      expect(AiNutritionService.isQuickOrSingleMealQuery('Vreau o masa rapida de 15 min'), isTrue);
      expect(AiNutritionService.isQuickOrSingleMealQuery('Ce sa mananc la pranz?'), isTrue);
      expect(AiNutritionService.isQuickOrSingleMealQuery('O gustare sanatoasa'), isTrue);
      expect(AiNutritionService.isQuickOrSingleMealQuery('Plan alimentar complet pe toata ziua'), isFalse);
      expect(AiNutritionService.isQuickOrSingleMealQuery('Generează Plan Alimentar (4 Mese)'), isFalse);
      expect(AiNutritionService.isQuickOrSingleMealQuery('Meniu pe o zi'), isFalse);
    });

    test('AI Nutrition Service generates 1 single tailored recipe for quick meal queries', () async {
      final aiService = AiNutritionService();
      final profile = UserProfile(
        id: 'test-u',
        username: 'liviu',
        firstName: 'Liviu',
        lastName: 'Oloi',
        sex: 'MALE',
        birthDate: DateTime(1994, 6, 15),
        heightCm: 182.0,
        profileStartWeight: 98.4,
        dailyTargetCalories: 2300,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final cuttingMission = Mission(
        id: 'm-1',
        userId: 'test-u',
        missionType: MissionType.cutting,
        missionStartWeight: 98.4,
        targetWeight: 90.0,
        startedAt: DateTime(2026, 10, 1),
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );

      final singleMeal = await aiService.generateCustomMealPlan(
        profile: profile,
        activeMission: cuttingMission,
        userPreferences: 'O recomandare rapida de masa',
      );

      expect(singleMeal.length, 1);
      expect(singleMeal.first.title.toLowerCase().contains('rapid') || singleMeal.first.title.toLowerCase().contains('15 min'), isTrue);

      final chatReply = await aiService.chatConsultation(
        history: [],
        userMessage: 'O recomandare rapida de masa',
        profile: profile,
        activeMission: cuttingMission,
      );

      // Verify the chat consultation gives a warm quick meal recommendation and does not dump the 4-meal plan
      expect(chatReply.contains('12-15 minute') || chatReply.contains('Tigaie Rapidă'), isTrue);
      expect(chatReply.contains('4. Cină Ușoară'), isFalse);
    });
  });
}

