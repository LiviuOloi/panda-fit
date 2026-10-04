import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../missions/domain/mission_model.dart';
import '../../profile/domain/profile_model.dart';
import '../domain/recipe_model.dart';

class AiNutritionService {
  final String? _apiKey;

  AiNutritionService([this._apiKey]);

  static const String _systemPrompt = '''
You are the PandaFit AI Head Nutritionist & Metabolic Coach.
Your goal is to design personalized, glycemic-optimized, sustainable meal plans for users tracking their health, body composition, and HbA1c/glycemic stability.

STRICT DOMAIN RULES:
1. Weighing Protocol:
   - Meat/Poultry/Fish: Always specified in RAW / uncooked grams.
   - Rice/Grains/Pasta: Always specified in DRY / uncooked grams.
   - Vegetables: Always specified in RAW or FROZEN grams (for high-volume fiber).
   - Cooking Oils/Fats: Always measured in grams or ml (never "a splash").
2. Glycemic Invariants:
   - Low glycemic index complex carbs (e.g. oats, graham/whole wheat, basmati/panzani rice, sweet potatoes).
   - Elevated dietary fiber with large vegetable volumes.
   - Lean proteins (cottage cheese light, chicken breast, egg whites, greek yogurt 2%, fish).
3. Return response in valid JSON array format when generating meal templates.
''';

  /// Generates personalized meal recommendations based on biometrics, active mission, and user preferences
  Future<List<MealRecipe>> generateCustomMealPlan({
    required UserProfile profile,
    required Mission activeMission,
    required String userPreferences,
  }) async {
    final apiKey = _apiKey ?? const String.fromEnvironment('GEMINI_API_KEY');

    if (apiKey.isNotEmpty) {
      try {
        final model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: apiKey,
          systemInstruction: Content.system(_systemPrompt),
        );

        final isCutting = activeMission.missionType == MissionType.cutting;
        final prompt = '''
User Biometrics:
- Age: ${profile.age} years old
- Sex: ${profile.sex}
- Height: ${profile.heightCm} cm
- Start Weight: ${profile.profileStartWeight} kg
- Target Weight: ${activeMission.targetWeight} kg
- Mission Focus: ${isCutting ? "CUTTING (Healthy sustainable fat loss deficit)" : "BULKING (Controlled lean mass surplus)"}
- Baseline Target Calories: ${profile.dailyTargetCalories} kcal/day
- User Specific Dietary Preferences / Exclusions: "$userPreferences"

Please generate 3 tailored meal recipes (e.g., 1 Breakfast, 1 Lunch/Snack, 1 Custom Dinner) optimized for these biometrics and preferences.
Return ONLY a valid JSON array matching this exact schema:
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
      } catch (_) {
        // Fallback to offline rule-based generator
      }
    }

    // Intelligent Offline Generator matching user metrics
    return _generateOfflineTailoredPlan(profile, activeMission, userPreferences);
  }

  /// Interactive conversational consultation with Panda Coach AI
  Future<String> chatConsultation({
    required List<Map<String, String>> history,
    required String userMessage,
    required UserProfile profile,
    required Mission activeMission,
  }) async {
    final apiKey = _apiKey ?? const String.fromEnvironment('GEMINI_API_KEY');

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
          contents.add(isUser ? Content.text(msg['text']!) : Content.model([TextPart(msg['text']!)]));
        }
        contents.add(Content.text('User biometrics: ${profile.age}yo, ${profile.heightCm}cm, ${profile.profileStartWeight}kg -> target ${activeMission.targetWeight}kg (${activeMission.missionType.name}). User question: $userMessage'));

        final response = await model.generateContent(contents);
        return response.text ?? 'I could not generate an answer right now.';
      } catch (e) {
        return 'Connection error with AI service: $e';
      }
    }

    // Offline rule-based smart response
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

    final proteinSource = isFishLover
        ? 'Wild Salmon Fillet / White Fish'
        : isNoPork
            ? 'Lean Chicken or Turkey Breast'
            : 'Tender Lean Beef / Pork Collar (weighed raw)';

    final carbSource = isCutting ? '100g Panzani / Basmati Rice (dry state)' : '140g Panzani Rice / Sweet Potato';

    return [
      MealRecipe(
        id: '',
        category: 'BREAKFAST',
        title: isNoDairy ? 'Panda Power Egg White & Avocado Bowl' : 'High-Protein Omelet & Light Cottage',
        calories: isCutting ? 580 : 680,
        proteinG: 44.0,
        carbsG: 45.0,
        fatG: 22.0,
        instructions: 'Whisk 3 eggs (or 2 whole + 2 whites). Sauté 200g mixed veggies in 5g measured oil. Serve with graham bread.',
        ingredients: [
          const RecipeIngredient(name: 'Whole Eggs', amount: '3 pcs', state: 'raw'),
          RecipeIngredient(
            name: isNoDairy ? 'Avocado (Weighed)' : 'Cottage Cheese Light (3%)',
            amount: isNoDairy ? '50g' : '100g',
            state: 'ready',
          ),
          const RecipeIngredient(name: 'Green Veggies (Broccoli/Beans)', amount: '200g', state: 'frozen/raw'),
          const RecipeIngredient(name: 'Graham / Whole Wheat Bread', amount: '70g', state: 'ready'),
          const RecipeIngredient(name: 'Olive Oil', amount: '5g', state: 'measured'),
        ],
      ),
      MealRecipe(
        id: '',
        category: 'DINNER',
        title: 'Custom AI Dinner: $proteinSource & Glycemic Fiber',
        calories: isCutting ? 640 : 780,
        proteinG: 58.0,
        carbsG: isCutting ? 70.0 : 95.0,
        fatG: 12.0,
        instructions: 'Cook seasoned raw protein and veggies. Boil dry weighed grains. Serve with crunchy brine pickles for probiotics.',
        ingredients: [
          RecipeIngredient(name: proteinSource, amount: isCutting ? '220g' : '260g', state: 'raw'),
          RecipeIngredient(name: carbSource, amount: isCutting ? '100g' : '135g', state: 'dry/uncooked'),
          const RecipeIngredient(name: 'Mixed Low-GI Veggies', amount: '280g', state: 'frozen/raw'),
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
    if (lower.contains('inlocui') || lower.contains('schimb') || lower.contains('replace')) {
      return 'Sigur! Conform ghidului PandaFit:\n- Orezul uscat (100g) poate fi înlocuit cu ~350g Cartofi Dulci sau ~80g Fulgi de Ovăz integrali.\n- Puiul crud (200g) poate fi înlocuit cu 220g File de Păstrăv/Somon sau 200g Mușchiuleț de Vită slabă.\nToate gramajele rămân calculate în stare brută/crudă pentru acuratețe maximă!';
    }
    return 'Am analizat profilul tău (${profile.age} ani, ${profile.heightCm} cm, pornire de la ${profile.profileStartWeight} kg către ținta de ${activeMission.targetWeight} kg în faza ${activeMission.missionType.name.toUpperCase()}).\nPentru a menține deficitul optim, recomandăm menținerea carbohidraților complecși la mesele din jurul antrenamentului și cântărirea strictă în stare crudă a proteinelor!';
  }
}
