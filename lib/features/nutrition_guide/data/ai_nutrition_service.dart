import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../core/utils/calculation_engine.dart';
import '../../missions/domain/mission_model.dart';
import '../../profile/domain/profile_model.dart';
import '../domain/recipe_model.dart';

class AiNutritionService {
  final String? _apiKey;

  AiNutritionService([this._apiKey]);

  static const String _systemPrompt = '''
You are the PandaFit AI Head Nutritionist, Metabolic Coach & Culinary Strategist.
Your mission is to provide world-class, personalized nutritional coaching, glycemic optimization, and culinary strategies.

CORE PRINCIPLES & METABOLIC INVARIANTS:
1. Basal Metabolic Rate (BMR) & Maintenance (TDEE):
   - You understand Mifflin-St Jeor formulas.
   - For CUTTING: 400-500 kcal deficit below maintenance.
   - For BULKING: 250-350 kcal lean surplus above maintenance.

2. STRICT WEIGHING PROTOCOL (PANDAFIT INVARIANT):
   - Meat/Fish/Poultry: Always specified in RAW / uncooked grams (moisture loss during cooking varies).
   - Rice/Grains/Pasta: Always specified in DRY / uncooked grams (carbohydrate density changes 2.5-3x after boiling).
   - Vegetables: Always specified in RAW or FROZEN grams (fiber & micronutrient preservation).
   - Cooking Oils/Fats: Always measured in grams or ml (never free-poured).

3. GLYCEMIC & METABOLIC OPTIMIZATION:
   - Prioritize low-to-medium glycemic index carbs (Basmati/Panzani rice, sweet potatoes, oats, whole wheat/Graham bread).
   - High volume fiber veggies (broccoli, green beans, mushrooms, zucchini, leafy greens, peppers).
   - High quality protein sources (chicken breast, wild salmon, lean beef, eggs, 2-3% cottage cheese, Greek yogurt).
   - Friendly, clear, and encouraging tone. You communicate naturally in Romanian or English (matching the user's language).
''';

  Future<List<MealRecipe>> generateCustomMealPlan({
    required UserProfile profile,
    required Mission activeMission,
    required String userPreferences,
    String? customApiKey,
  }) async {
    final apiKey = customApiKey ?? _apiKey ?? const String.fromEnvironment('GEMINI_API_KEY');

    final bmr = CalculationEngine.calculateBMR(
      weightKg: profile.profileStartWeight,
      heightCm: profile.heightCm,
      age: profile.age,
      sex: profile.sex,
    );
    final maintenance = CalculationEngine.calculateMaintenanceCalories(
      weightKg: profile.profileStartWeight,
      heightCm: profile.heightCm,
      age: profile.age,
      sex: profile.sex,
    );
    final isCutting = activeMission.missionType == MissionType.cutting;
    final recommendedTarget = isCutting ? maintenance - 450 : maintenance + 300;

    if (apiKey.isNotEmpty) {
      try {
        final model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: apiKey,
          systemInstruction: Content.system(_systemPrompt),
        );

        final prompt = '''
User Biometrics:
- Age: ${profile.age} years old
- Sex: ${profile.sex}
- Height: ${profile.heightCm} cm
- Start Weight: ${profile.profileStartWeight} kg
- Target Weight: ${activeMission.targetWeight} kg
- Mission Focus: ${isCutting ? "CUTTING (Deficit for sustainable fat loss)" : "BULKING (Controlled lean mass surplus)"}
- Calculated BMR: $bmr kcal/day
- Calculated Maintenance (TDEE): $maintenance kcal/day
- Recommended Daily Target: $recommendedTarget kcal/day
- Specific Dietary Request / Preferences: "$userPreferences"

Please generate 3 creative, delicious, low-glycemic meal recipes (e.g. 1 Breakfast, 1 Lunch/Snack, 1 Dinner) adapted to these goals and preferences.
Weighing rules: Meat=raw, Rice/Carbs=dry/uncooked, Veggies=frozen/raw, Oil=measured.
Return ONLY a valid JSON array matching this exact schema without markdown wrap:
[
  {
    "category": "DINNER",
    "title": "Recipe Title",
    "calories": 650,
    "protein_g": 55.0,
    "carbs_g": 60.0,
    "fat_g": 14.0,
    "instructions": "Preparation and cooking details.",
    "ingredients": [
      {"name": "Chicken Breast", "amount": "220g", "state": "raw"},
      {"name": "Panzani Rice", "amount": "100g", "state": "dry/uncooked"},
      {"name": "Broccoli & Beans", "amount": "250g", "state": "frozen/raw"},
      {"name": "Olive Oil", "amount": "5g", "state": "measured"}
    ]
  }
]
''';

        final response = await model.generateContent([Content.text(prompt)]);
        final text = response.text;
        if (text != null) {
          final cleaned = _extractJson(text);
          final decoded = json.decode(cleaned) as List<dynamic>;
          return decoded.map((r) => MealRecipe.fromJson(r as Map<String, dynamic>)).toList();
        }
      } catch (e) {
        debugPrint('Gemini generateCustomMealPlan error: $e');
      }
    }

    // High-variety offline fallback generator
    return _generateOfflineTailoredPlan(profile, activeMission, userPreferences);
  }

  Future<String> chatConsultation({
    required List<Map<String, String>> history,
    required String userMessage,
    required UserProfile profile,
    required Mission activeMission,
    String? customApiKey,
  }) async {
    final apiKey = customApiKey ?? _apiKey ?? const String.fromEnvironment('GEMINI_API_KEY');

    final bmr = CalculationEngine.calculateBMR(
      weightKg: profile.profileStartWeight,
      heightCm: profile.heightCm,
      age: profile.age,
      sex: profile.sex,
    );
    final maintenance = CalculationEngine.calculateMaintenanceCalories(
      weightKg: profile.profileStartWeight,
      heightCm: profile.heightCm,
      age: profile.age,
      sex: profile.sex,
    );
    final isCutting = activeMission.missionType == MissionType.cutting;
    final recommendedTarget = isCutting ? maintenance - 450 : maintenance + 300;

    if (apiKey.isNotEmpty) {
      try {
        final model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: apiKey,
          systemInstruction: Content.system(_systemPrompt),
        );

        final contents = <Content>[];
        for (final msg in history) {
          final isUser = msg['role'] == 'user';
          final text = msg['text'] ?? '';
          contents.add(isUser ? Content.text(text) : Content.model([TextPart(text)]));
        }

        contents.add(
          Content.text('''
Context:
- User: ${profile.firstName} (${profile.age}yo, ${profile.heightCm}cm, ${profile.profileStartWeight}kg -> goal ${activeMission.targetWeight}kg ${activeMission.missionType.name.toUpperCase()}).
- BMR: $bmr kcal, Maintenance TDEE: $maintenance kcal, Target: $recommendedTarget kcal.
- User Question: $userMessage
'''),
        );

        final response = await model.generateContent(contents);
        return response.text ?? 'I could not generate an answer right now.';
      } catch (e) {
        return 'Error communicating with Gemini AI: $e. Please verify your API key in Settings.';
      }
    }

    return _generateOfflineChatResponse(userMessage, profile, activeMission);
  }

  String _extractJson(String rawText) {
    final int start = rawText.indexOf('[');
    final int end = rawText.lastIndexOf(']');
    if (start != -1 && end != -1 && end > start) {
      return rawText.substring(start, end + 1);
    }
    return rawText;
  }

  List<MealRecipe> _generateOfflineTailoredPlan(
    UserProfile profile,
    Mission activeMission,
    String userPreferences,
  ) {
    final isCutting = activeMission.missionType == MissionType.cutting;
    final lowerPref = userPreferences.toLowerCase();

    final isNoPork = lowerPref.contains('porc') || lowerPref.contains('pork') || lowerPref.contains('fara porc');
    final isFishLover = lowerPref.contains('peste') || lowerPref.contains('fish') || lowerPref.contains('somon');
    final isNoDairy = lowerPref.contains('lactate') || lowerPref.contains('dairy') || lowerPref.contains('lactoza');
    final isBeefLover = lowerPref.contains('vita') || lowerPref.contains('beef');

    final rand = Random();
    final option = rand.nextInt(3);

    if (isFishLover || option == 0) {
      return [
        MealRecipe(
          id: '',
          category: 'BREAKFAST',
          title: 'Salmon Avocado Protein Toast & Eggs',
          calories: isCutting ? 520 : 640,
          proteinG: 42.0,
          carbsG: 40.0,
          fatG: 20.0,
          instructions: 'Toast whole wheat bread. Layer smoked or pan-seared salmon with sliced avocado and soft poached eggs.',
          ingredients: [
            const RecipeIngredient(name: 'Whole Eggs', amount: '2 pcs', state: 'raw'),
            const RecipeIngredient(name: 'Wild Salmon / Smoked Trout', amount: '100g', state: 'raw'),
            const RecipeIngredient(name: 'Avocado', amount: '40g', state: 'ready'),
            const RecipeIngredient(name: 'Graham Bread', amount: '60g', state: 'ready'),
          ],
        ),
        MealRecipe(
          id: '',
          category: 'DINNER',
          title: 'Oven-Baked Wild Salmon & Basmati Matrix',
          calories: isCutting ? 650 : 800,
          proteinG: 52.0,
          carbsG: isCutting ? 65.0 : 90.0,
          fatG: 18.0,
          instructions: 'Bake seasoned raw salmon fillet at 190°C. Serve over steamed dry-measured basmati rice and roasted broccoli/asparagus.',
          ingredients: [
            RecipeIngredient(name: 'Wild Salmon Fillet', amount: isCutting ? '220g' : '260g', state: 'raw'),
            RecipeIngredient(name: 'Basmati Rice', amount: isCutting ? '100g' : '135g', state: 'dry/uncooked'),
            const RecipeIngredient(name: 'Broccoli & Green Asparagus', amount: '250g', state: 'frozen/raw'),
            const RecipeIngredient(name: 'Pickles in Brine', amount: '60g', state: 'ready'),
            const RecipeIngredient(name: 'Olive Oil', amount: '5g', state: 'measured'),
          ],
        ),
      ];
    }

    if (isBeefLover || (!isNoPork && option == 1)) {
      return [
        MealRecipe(
          id: '',
          category: 'BREAKFAST',
          title: 'Omelet with Light Cottage & Mushrooms',
          calories: isCutting ? 490 : 590,
          proteinG: 46.0,
          carbsG: 35.0,
          fatG: 16.0,
          instructions: 'Whisk 3 eggs, sauté mushrooms with cooking spray/oil, fold in light cottage cheese.',
          ingredients: [
            const RecipeIngredient(name: 'Eggs', amount: '3 pcs', state: 'raw'),
            RecipeIngredient(name: isNoDairy ? 'Avocado' : 'Cottage Cheese 3%', amount: isNoDairy ? '40g' : '100g', state: 'ready'),
            const RecipeIngredient(name: 'Sautéed Mushrooms', amount: '150g', state: 'frozen/raw'),
            const RecipeIngredient(name: 'Graham Bread', amount: '60g', state: 'ready'),
          ],
        ),
        MealRecipe(
          id: '',
          category: 'DINNER',
          title: 'Tender Lean Beef & Sweet Potato Wedges',
          calories: isCutting ? 660 : 790,
          proteinG: 56.0,
          carbsG: isCutting ? 65.0 : 90.0,
          fatG: 16.0,
          instructions: 'Grill lean beef cut. Air fry raw weighed sweet potato wedges with sea salt and smoked paprika.',
          ingredients: [
            RecipeIngredient(name: 'Lean Beef Sirloin / Tenderloin', amount: isCutting ? '220g' : '260g', state: 'raw'),
            RecipeIngredient(name: 'Sweet Potatoes', amount: isCutting ? '250g' : '350g', state: 'raw'),
            const RecipeIngredient(name: 'Green Beans & Garlic', amount: '200g', state: 'frozen/raw'),
            const RecipeIngredient(name: 'Olive Oil', amount: '5g', state: 'measured'),
          ],
        ),
      ];
    }

    return [
      MealRecipe(
        id: '',
        category: 'BREAKFAST',
        title: 'Panda High-Protein Power Omelet',
        calories: isCutting ? 540 : 640,
        proteinG: 45.0,
        carbsG: 42.0,
        fatG: 18.0,
        instructions: 'Whisk 3 eggs with spinach and green beans. Serve with whole grain toast and light cheese.',
        ingredients: [
          const RecipeIngredient(name: 'Whole Eggs', amount: '3 pcs', state: 'raw'),
          const RecipeIngredient(name: 'Green Veggies', amount: '200g', state: 'frozen/raw'),
          const RecipeIngredient(name: 'Graham Bread', amount: '70g', state: 'ready'),
          const RecipeIngredient(name: 'Cottage Cheese Light (3%)', amount: '100g', state: 'ready'),
          const RecipeIngredient(name: 'Olive Oil', amount: '5g', state: 'measured'),
        ],
      ),
      MealRecipe(
        id: '',
        category: 'DINNER',
        title: 'Golden Chicken Breast & Panzani Rice Matrix',
        calories: isCutting ? 630 : 760,
        proteinG: 58.0,
        carbsG: isCutting ? 70.0 : 95.0,
        fatG: 10.0,
        instructions: 'Cook seasoned chicken in non-stick pan with measured oil. Boil dry rice. Serve with crunchy pickles in brine.',
        ingredients: [
          RecipeIngredient(name: 'Chicken Breast', amount: isCutting ? '220g' : '260g', state: 'raw'),
          RecipeIngredient(name: 'Panzani Rice', amount: isCutting ? '100g' : '135g', state: 'dry/uncooked'),
          const RecipeIngredient(name: 'Low-GI Veggies', amount: '250g', state: 'frozen/raw'),
          const RecipeIngredient(name: 'Pickles in Brine', amount: '80g', state: 'ready'),
          const RecipeIngredient(name: 'Olive Oil', amount: '5g', state: 'measured'),
        ],
      ),
    ];
  }

  String _generateOfflineChatResponse(
    String userMessage,
    UserProfile profile,
    Mission activeMission,
  ) {
    final lower = userMessage.toLowerCase();
    final bmr = CalculationEngine.calculateBMR(
      weightKg: profile.profileStartWeight,
      heightCm: profile.heightCm,
      age: profile.age,
      sex: profile.sex,
    );
    final maintenance = CalculationEngine.calculateMaintenanceCalories(
      weightKg: profile.profileStartWeight,
      heightCm: profile.heightCm,
      age: profile.age,
      sex: profile.sex,
    );
    final isCutting = activeMission.missionType == MissionType.cutting;
    final recommendedTarget = isCutting ? maintenance - 450 : maintenance + 300;

    if (lower.contains('menten') || lower.contains('calor') || lower.contains('bmr') || lower.contains('tdee')) {
      return '''
📊 **Analiza Metabolică PandaFit:**
- **BMR:** ~$bmr kcal/zi (energia consumată în repaus total).
- **Mentenanță (TDEE):** ~$maintenance kcal/zi (caloriile la care greutatea stagnează).
- **Ținta Recomandată (${activeMission.missionType.name.toUpperCase()}):** ~$recommendedTarget kcal/zi ${isCutting ? '(-450 kcal deficit pentru ardere sustenabilă a grăsimilor)' : '(+300 kcal surplus pentru hipertrofie curată)'}.

💡 *Sfat: Pentru a discuta liber orice întrebare sau a genera rețete nelimitate, conectează cheia gratuită Gemini API din ecranul Panda Eats AI!*''';
    }

    if (lower.contains('inlocui') || lower.contains('schimb') || lower.contains('replace')) {
      return '''
🔄 **Reguli de Echivalență PandaFit:**
- **Orez Uscat (100g = ~350 kcal, 75g Carbs):** = ~350g Cartofi Dulci cruzi = ~80g Fulgi de Ovăz uscați = ~130g Pâine Graham.
- **Piept de Pui Crud (200g = ~220 kcal, 46g Proteină):** = ~220g File de Somon proaspăt = ~200g Mușchiuleț de Vită slabă = ~230g Păstrăv.
*Toate gramajele rămân strict măsurate în stare crudă/uscată!*''';
    }

    return '''
Salut ${profile.firstName}! Sunt Panda AI Coach. 
Profilul tău actual este setat pe faza **${activeMission.missionType.name.toUpperCase()}** (${profile.profileStartWeight} kg → ținta ${activeMission.targetWeight} kg).
Ținta ta zilnică optimizată este de **~$recommendedTarget kcal/zi**.

Poți să-mi ceri idei de mese, ajustări de gramaje, sau activează cheia gratuită **Gemini Live AI** pentru conversații fără limite și căutare pe web!''';
  }
}

