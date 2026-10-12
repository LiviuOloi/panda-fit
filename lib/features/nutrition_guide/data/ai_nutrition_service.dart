import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../core/utils/calculation_engine.dart';
import '../../missions/domain/mission_model.dart';
import '../../profile/domain/profile_model.dart';
import '../domain/recipe_model.dart';

class AiConsultationResult {
  final String markdownReply;
  final List<MealRecipe> recipes;

  const AiConsultationResult({
    required this.markdownReply,
    this.recipes = const [],
  });
}

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

  static const List<String> _candidateModels = [
    'gemini-2.0-flash',
    'gemini-1.5-flash-latest',
    'gemini-1.5-flash',
    'gemini-2.0-flash-exp',
    'gemini-1.5-pro-latest',
    'gemini-1.5-pro',
    'gemini-pro',
  ];

  static bool isQuickOrSingleMealQuery(String text) {
    final lower = text.toLowerCase().trim();
    if (lower.contains('plan complet') ||
        lower.contains('plan alimentar') ||
        lower.contains('meniu complet') ||
        lower.contains('toate mesele') ||
        lower.contains('4 mese') ||
        lower.contains('meniu pe o zi') ||
        lower.contains('pe toata ziua') ||
        lower.contains('pe toată ziua') ||
        lower.contains('zi întreagă') ||
        lower.contains('zi intreaga')) {
      return false;
    }

    return lower.contains('rapid') ||
        lower.contains('repede') ||
        lower.contains('15 min') ||
        lower.contains('pe fug') ||
        lower.contains('quick') ||
        lower.contains('fast') ||
        lower.contains('acum') ||
        lower.contains('o masa') ||
        lower.contains('o masă') ||
        lower.contains('o reteta') ||
        lower.contains('o rețetă') ||
        lower.contains('o recomandare') ||
        lower.contains('o idee') ||
        lower.contains('o gustare') ||
        lower.contains('un pranz') ||
        lower.contains('un prânz') ||
        lower.contains('o cina') ||
        lower.contains('o cină') ||
        lower.contains('un mic dejun') ||
        lower.contains('mic dejun') ||
        lower.contains('micul dejun') ||
        lower.contains('breakfast') ||
        lower.contains('pranz') ||
        lower.contains('prânz') ||
        lower.contains('lunch') ||
        lower.contains('cina') ||
        lower.contains('cină') ||
        lower.contains('dinner') ||
        lower.contains('gustare') ||
        lower.contains('snack');
  }

  Future<List<MealRecipe>> generateCustomMealPlan({
    required UserProfile profile,
    required Mission activeMission,
    required String userPreferences,
    String? customApiKey,
    Uint8List? imageBytes,
    String? mimeType,
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
    final isSingleMeal = isQuickOrSingleMealQuery(userPreferences);

    if (apiKey.isNotEmpty) {
      final prompt = isSingleMeal
          ? '''
User Biometrics:
- Age: ${profile.age} years old
- Sex: ${profile.sex}
- Height: ${profile.heightCm} cm
- Start Weight: ${profile.profileStartWeight} kg
- Target Weight: ${activeMission.targetWeight} kg
- Mission Focus: ${isCutting ? "CUTTING (Deficit for sustainable fat loss)" : "BULKING (Controlled lean mass surplus)"}
- Calculated BMR: $bmr kcal/day
- Calculated Maintenance (TDEE): $maintenance kcal/day
- Target Daily Calories: $recommendedTarget kcal/day
- Specific Meal Request: "$userPreferences"
${imageBytes != null ? "NOTE: Nutrition label photo attached. Extract macros and incorporate product with exact weighed grams." : ""}

Please generate 1 single practical, highly delicious and macro-optimized recipe matching the user's specific request.
Category must be one of: "LUNCH", "DINNER", "BREAKFAST", "SNACK", or "CUSTOM".
Weighing rules: Meat=raw, Rice/Carbs=dry/uncooked, Veggies=frozen/raw, Oil=measured.
Return ONLY a valid JSON array containing this 1 recipe matching this exact schema:
[
  {
    "category": "LUNCH",
    "title": "Tigaie Rapidă Anabolică de Pui cu Orez & Legume",
    "calories": 600,
    "protein_g": 52.0,
    "carbs_g": 55.0,
    "fat_g": 12.0,
    "instructions": "Step-by-step fast cooking instructions.",
    "ingredients": [
      {"name": "Piept de Pui", "amount": "220g", "state": "raw"},
      {"name": "Orez Basmati", "amount": "80g", "state": "dry/uncooked"},
      {"name": "Legume Verzi Asortate", "amount": "200g", "state": "frozen/raw"},
      {"name": "Ulei de Măsline", "amount": "5g", "state": "measured"}
    ]
  }
]
'''
          : '''
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
${imageBytes != null ? "NOTE: An image of a food product or nutrition label is attached. Inspect its ingredients, macros per 100g, and construct customized recipes featuring or incorporating this product with precise weighed portions!" : ""}

Please generate a full daily meal plan consisting of 4 distinct meals:
1. "BREAKFAST" (Micul Dejun)
2. "SNACK" (Gustare)
3. "LUNCH" (Prânzul)
4. "DINNER" (Cina)
Total combined calories should closely match ~$recommendedTarget kcal/day.
Weighing rules: Meat=raw, Rice/Carbs=dry/uncooked, Veggies=frozen/raw, Oil=measured.
Return ONLY a valid JSON array matching this exact schema without markdown wrap:
[
  {
    "category": "BREAKFAST",
    "title": "Breakfast Title",
    "calories": 520,
    "protein_g": 42.0,
    "carbs_g": 40.0,
    "fat_g": 18.0,
    "instructions": "Preparation details.",
    "ingredients": [
      {"name": "Whole Eggs", "amount": "3 pcs", "state": "raw"},
      {"name": "Cottage Cheese 3%", "amount": "100g", "state": "ready"}
    ]
  },
  {
    "category": "SNACK",
    "title": "Snack Title",
    "calories": 280,
    "protein_g": 22.0,
    "carbs_g": 28.0,
    "fat_g": 8.0,
    "instructions": "Preparation details.",
    "ingredients": [
      {"name": "Greek Yogurt 2%", "amount": "150g", "state": "ready"}
    ]
  },
  {
    "category": "LUNCH",
    "title": "Lunch Title",
    "calories": 650,
    "protein_g": 55.0,
    "carbs_g": 65.0,
    "fat_g": 12.0,
    "instructions": "Preparation details.",
    "ingredients": [
      {"name": "Chicken Breast", "amount": "220g", "state": "raw"},
      {"name": "Basmati Rice", "amount": "100g", "state": "dry/uncooked"}
    ]
  },
  {
    "category": "DINNER",
    "title": "Dinner Title",
    "calories": 600,
    "protein_g": 50.0,
    "carbs_g": 45.0,
    "fat_g": 16.0,
    "instructions": "Preparation details.",
    "ingredients": [
      {"name": "Wild Salmon", "amount": "200g", "state": "raw"},
      {"name": "Sweet Potatoes", "amount": "200g", "state": "raw"}
    ]
  }
]
''';

      for (final modelName in _candidateModels) {
        try {
          final model = GenerativeModel(
            model: modelName,
            apiKey: apiKey,
            systemInstruction: Content.system(_systemPrompt),
          );

          final contentParts = <Part>[];
          if (imageBytes != null) {
            contentParts.add(DataPart(mimeType ?? 'image/jpeg', imageBytes));
          }
          contentParts.add(TextPart(prompt));

          final response = await model.generateContent([Content.multi(contentParts)]);
          final text = response.text;
          if (text != null) {
            final cleaned = _extractJson(text);
            final decoded = json.decode(cleaned) as List<dynamic>;
            return decoded.map((r) => MealRecipe.fromJson(r as Map<String, dynamic>)).toList();
          }
        } catch (e) {
          debugPrint('Gemini generateCustomMealPlan tried $modelName error: $e');
        }
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
    Uint8List? imageBytes,
    String? mimeType,
  }) async {
    final result = await chatConsultationAdvanced(
      history: history,
      userMessage: userMessage,
      profile: profile,
      activeMission: activeMission,
      customApiKey: customApiKey,
      imageBytes: imageBytes,
      mimeType: mimeType,
    );
    return result.markdownReply;
  }

  Future<AiConsultationResult> chatConsultationAdvanced({
    required List<Map<String, String>> history,
    required String userMessage,
    required UserProfile profile,
    required Mission activeMission,
    String? customApiKey,
    Uint8List? imageBytes,
    String? mimeType,
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

    final dynamicSystemPrompt = '''
You are Panda AI — a world-class, ultra-intelligent, energetic, friendly, and deeply knowledgeable fitness coach, nutritionist, and wellness strategist for PandaFit.
You converse naturally, fluently, and casually, with the conversational freedom, empathy, intellectual versatility, and deep reasoning of ChatGPT and Gemini.
You are NEVER a rigid robot, questionnaire, or monotonous meal-vending machine. You speak like an awesome personal coach and supportive training partner!

CONVERSATIONAL FREEDOM & TOPIC BREADTH:
- You love talking freely about ANYTHING the user wants:
  * Nutrition, macros, fiber, micronutrients, glycemic index, meal ideas, snacks
  * Workout splits (Push/Pull/Legs, Upper/Lower, Full Body), hypertrophy, rep ranges, cardio, swimming
  * Fat loss physiology, weight plateaus, and why scale weight fluctuates daily (water retention, glycogen stores, sodium, digestive transit)
  * Supplements: creatine monohydrate, whey isolate, omega-3, vitamin D3/K2, caffeine, magnesium
  * Sleep quality, recovery, stress management, cortisol, appetite hormones (ghrelin/leptin)
  * Fighting evening cravings, forming habits, building mental discipline and consistency
  * Everyday casual banter, encouragement, check-ins, or humor!
- Adapt directly to the user. Never give cookie-cutter or repetitive answers.

CRITICAL LANGUAGE RULE:
- If the user writes in Romanian, you MUST respond completely and fluently in ROMANIAN using natural, warm, friendly phrasing ("tu", "salut!", "hai să vedem", "fii atent", "nu te îngrijora", "super tare!").
- If the user writes in English, respond in English.
- NEVER respond in stiff or robotic language.

USER BIOMETRIC CONTEXT (KNOWLEDGE BASE):
- Name: ${profile.firstName}
- Age: ${profile.age} years old
- Sex: ${profile.sex}
- Height: ${profile.heightCm} cm
- Starting Weight: ${profile.profileStartWeight} kg
- Target Weight: ${activeMission.targetWeight} kg (${isCutting ? "CUTTING / Fat Loss: -450 kcal deficit" : "BULKING / Lean Muscle: +300 kcal surplus"})
- Basal Metabolic Rate (BMR): ~$bmr kcal/day
- Maintenance TDEE: ~$maintenance kcal/day
- Target Daily Calories: ~$recommendedTarget kcal/day
* IMPORTANT: Use these numbers intelligently when relevant to personalize answers, but DO NOT mechanically recite or dump this entire profile in every reply if the user just asked a general or casual question.

PANDAFIT INVARIANTS (WHEN DISCUSSING MEALS OR RECIPES):
1. Weighing Protocol: Meat is ALWAYS weighed RAW / uncooked, Rice/Carbs DRY / uncooked, Veggies RAW / frozen, Oils measured in grams/ml.
2. Glycemic Quality: Low/medium GI carbs (Panzani/Basmati rice, sweet potatoes, oats), high-fiber veggies, lean protein.

INTERACTIVE RECIPE CARDS INTEGRATION:
- If and ONLY IF the user explicitly asks for recipes, meal ideas, a quick dish (15 min), or a daily meal plan:
  1. Write your delicious, friendly culinary and nutrition advice in natural markdown text.
  2. At the very end of your response, output a JSON block inside ```json:recipes ... ```:
```json:recipes
[
  {
    "category": "BREAKFAST",
    "title": "Numele Rețetei",
    "ingredients": [
      {"name": "Ingredient 1", "amount": "200g", "state": "raw"},
      {"name": "Ingredient 2", "amount": "80g", "state": "dry/uncooked"}
    ],
    "calories": 520,
    "protein_g": 45.0,
    "carbs_g": 50.0,
    "fat_g": 12.0,
    "instructions": "Instrucțiuni clare de preparare..."
  }
]
```
  Allowed categories: "BREAKFAST", "SNACK", "LUNCH", "DINNER", "CUSTOM".
- If the user is NOT asking for a meal recipe (e.g. asking about workouts, motivation, sleep, physiology, creatine, or casual chat), DO NOT output any json block! Just converse freely and naturally!

CHECKING LABELS & FOOD PHOTOS (VISION):
- When the user sends a photo of a food item or nutrition label:
  * Read the ingredients & macronutrients table (Calories, Protein, Carbs, Sugars, Fat, Fiber).
  * Give a clear, friendly verdict on whether it fits their current goal (~$recommendedTarget kcal/day).
  * Recommend the exact weighed portion (in grams) to eat.
''';

    if (apiKey.isNotEmpty) {
      final validTurns = <Content>[];
      String? lastRole;

      for (int i = 0; i < history.length; i++) {
        final m = history[i];
        final role = m['role'] ?? '';
        final text = (m['text'] ?? '').trim();
        if (text.isEmpty) continue;

        // Skip until the first user message
        if (lastRole == null && role != 'user') continue;

        // Ensure strict alternation (user -> model -> user -> model)
        if (role == lastRole) continue;

        if (role == 'user') {
          validTurns.add(Content.text(text));
          lastRole = 'user';
        } else if (role == 'ai' || role == 'model') {
          validTurns.add(Content.model([TextPart(text)]));
          lastRole = 'model';
        }
      }

      // If validTurns is empty or ends with a model message, add the current userMessage (with image if present)
      if (validTurns.isEmpty || lastRole != 'user') {
        if (imageBytes != null) {
          final userText = userMessage.trim().isEmpty
              ? 'Please analyze this food product / nutrition label image. Extract its macronutrients per 100g, assess its glycemic quality, and calculate the exact weighed portion I should eat to fit my current goals.'
              : userMessage;
          validTurns.add(Content.multi([DataPart(mimeType ?? 'image/jpeg', imageBytes), TextPart(userText)]));
        } else {
          validTurns.add(Content.text(userMessage));
        }
      } else if (imageBytes != null) {
        // Replace the last user text turn with multimodal turn if image is present
        final userText = userMessage.trim().isEmpty
            ? 'Please analyze this food product / nutrition label image. Extract its macronutrients per 100g, assess its glycemic quality, and calculate the exact weighed portion I should eat to fit my current goals.'
            : userMessage;
        validTurns[validTurns.length - 1] = Content.multi([DataPart(mimeType ?? 'image/jpeg', imageBytes), TextPart(userText)]);
      }

      for (final modelName in _candidateModels) {
        try {
          final model = GenerativeModel(
            model: modelName,
            apiKey: apiKey,
            systemInstruction: Content.system(dynamicSystemPrompt),
          );

          final response = await model.generateContent(validTurns);
          final rawText = response.text;
          if (rawText != null && rawText.trim().isNotEmpty) {
            return _parseConsultationResponse(rawText);
          }
        } catch (e) {
          debugPrint('Gemini chatConsultation tried $modelName error: $e');
          try {
            final fallbackTurns = <Content>[
              Content.text('Instructions & Profile:\n$dynamicSystemPrompt'),
              ...validTurns,
            ];
            final model = GenerativeModel(model: modelName, apiKey: apiKey);
            final response = await model.generateContent(fallbackTurns);
            final rawText = response.text;
            if (rawText != null && rawText.trim().isNotEmpty) {
              return _parseConsultationResponse(rawText);
            }
          } catch (e2) {
            debugPrint('Gemini fallback chat error on $modelName: $e2');
          }
        }
      }
    }

    final offlineText = _generateOfflineChatResponse(userMessage, profile, activeMission);
    final lower = userMessage.toLowerCase();
    List<MealRecipe> offlineRecipes = [];
    if (lower.contains('plan') ||
        lower.contains('meniu') ||
        lower.contains('mese') ||
        isQuickOrSingleMealQuery(lower) ||
        lower.contains('retet') ||
        lower.contains('rețet')) {
      offlineRecipes = _generateOfflineTailoredPlan(profile, activeMission, userMessage);
    }
    return AiConsultationResult(markdownReply: offlineText, recipes: offlineRecipes);
  }

  AiConsultationResult _parseConsultationResponse(String rawText) {
    List<MealRecipe> recipes = [];
    String cleaned = rawText;

    // Look for ```json:recipes ... ``` or ```json [...] ```
    final blockRegex = RegExp(r'```(?:json:recipes|json)?\s*(\[[\s\S]*?\])\s*```', caseSensitive: false);
    final match = blockRegex.firstMatch(rawText);

    if (match != null) {
      final jsonBlock = match.group(1);
      if (jsonBlock != null) {
        try {
          final decoded = json.decode(jsonBlock) as List<dynamic>;
          recipes = decoded.map((e) => MealRecipe.fromJson(e as Map<String, dynamic>)).toList();
          cleaned = rawText.replaceAll(match.group(0)!, '').trim();
        } catch (e) {
          debugPrint('Error parsing recipe block from AI response: $e');
        }
      }
    }

    return AiConsultationResult(markdownReply: cleaned, recipes: recipes);
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

    final isSingleMeal = isQuickOrSingleMealQuery(lowerPref);

    final isNoPork = lowerPref.contains('porc') || lowerPref.contains('pork') || lowerPref.contains('fara porc');
    final isFishLover = lowerPref.contains('peste') || lowerPref.contains('pește') || lowerPref.contains('fish') || lowerPref.contains('somon');
    final isNoDairy = lowerPref.contains('lactate') || lowerPref.contains('dairy') || lowerPref.contains('lactoza');
    final isBeefLover = lowerPref.contains('vita') || lowerPref.contains('vită') || lowerPref.contains('beef');

    // Single meal recommendations
    if (isSingleMeal) {
      if (lowerPref.contains('mic dejun') || lowerPref.contains('micul dejun') || lowerPref.contains('breakfast')) {
        return [_createBreakfastRecipe(isCutting, isNoDairy)];
      }
      if (lowerPref.contains('gustar') || lowerPref.contains('snack')) {
        return [_createSnackRecipe(isCutting, isNoDairy)];
      }
      if (lowerPref.contains('cina') || lowerPref.contains('cină') || lowerPref.contains('dinner')) {
        return [_createDinnerRecipe(isCutting, isFishLover, isBeefLover, isNoPork)];
      }
      // Default single meal is the rapid 15-minute skillet
      return [_createQuickSkilletRecipe(isCutting, isFishLover, isNoDairy)];
    }

    // Full 4-meal plan
    return [
      _createBreakfastRecipe(isCutting, isNoDairy),
      _createSnackRecipe(isCutting, isNoDairy),
      _createLunchRecipe(isCutting, isFishLover),
      _createDinnerRecipe(isCutting, isFishLover, isBeefLover, isNoPork),
    ];
  }

  MealRecipe _createBreakfastRecipe(bool isCutting, bool isNoDairy) {
    return MealRecipe(
      id: '',
      category: 'BREAKFAST',
      title: 'Omletă Anabolică cu Legume Verzi & Toast',
      calories: isCutting ? 520 : 620,
      proteinG: 42.0,
      carbsG: 40.0,
      fatG: 18.0,
      instructions: 'Bate 3 ouă cu sare și piper. Trage la tigaie broccoli și fasolea verde în 5g ulei de măsline măsurat. Toarnă ouăle și servește cu brânză cottage și pâine graham.',
      ingredients: [
        const RecipeIngredient(name: 'Ouă Întregi', amount: '3 buc', state: 'raw'),
        RecipeIngredient(name: isNoDairy ? 'Avocado' : 'Brânză Cottage Light 3%', amount: isNoDairy ? '40g' : '100g', state: 'ready'),
        const RecipeIngredient(name: 'Broccoli & Fasole Verde', amount: '200g', state: 'frozen/raw'),
        const RecipeIngredient(name: 'Pâine Graham', amount: '70g', state: 'ready'),
        const RecipeIngredient(name: 'Ulei de Măsline', amount: '5g', state: 'measured'),
      ],
    );
  }

  MealRecipe _createSnackRecipe(bool isCutting, bool isNoDairy) {
    return MealRecipe(
      id: '',
      category: 'SNACK',
      title: 'Iaurt Grecesc cu Afine & Semințe Chia',
      calories: isCutting ? 280 : 340,
      proteinG: 22.0,
      carbsG: 28.0,
      fatG: 8.0,
      instructions: 'Amestecă iaurtul grecesc cu semințele de chia și afinele proaspete sau decongelate.',
      ingredients: [
        RecipeIngredient(name: isNoDairy ? 'Iaurt de Cocos/Soia' : 'Iaurt Grecesc 2%', amount: '150g', state: 'ready'),
        const RecipeIngredient(name: 'Afine', amount: '75g', state: 'raw'),
        const RecipeIngredient(name: 'Semințe de Chia', amount: '10g', state: 'raw'),
        const RecipeIngredient(name: 'Unt de Arahide 100%', amount: '10g', state: 'measured'),
      ],
    );
  }

  MealRecipe _createLunchRecipe(bool isCutting, bool isFishLover) {
    return MealRecipe(
      id: '',
      category: 'LUNCH',
      title: isFishLover
          ? 'Păstrăv la Cuptor cu Orez Basmati & Murături'
          : 'Piept de Pui la Grătar cu Orez Basmati & Legume',
      calories: isCutting ? 650 : 780,
      proteinG: 55.0,
      carbsG: isCutting ? 65.0 : 90.0,
      fatG: 12.0,
      instructions: 'Fierbe orezul Basmati (cântărit uscat). Gătește pieptul de pui sau peștele (cântărit crud) pe grătar/tigaie antiaderentă. Servește cu legume și murături în saramură.',
      ingredients: [
        RecipeIngredient(name: isFishLover ? 'File de Păstrăv / Somon' : 'Piept de Pui', amount: isCutting ? '220g' : '260g', state: 'raw'),
        RecipeIngredient(name: 'Orez Basmati / Panzani', amount: isCutting ? '100g' : '135g', state: 'dry/uncooked'),
        const RecipeIngredient(name: 'Legume Asortate', amount: '250g', state: 'frozen/raw'),
        const RecipeIngredient(name: 'Murături în Saramură', amount: '80g', state: 'ready'),
        const RecipeIngredient(name: 'Ulei de Măsline', amount: '5g', state: 'measured'),
      ],
    );
  }

  MealRecipe _createDinnerRecipe(bool isCutting, bool isFishLover, bool isBeefLover, bool isNoPork) {
    return MealRecipe(
      id: '',
      category: 'DINNER',
      title: isBeefLover
          ? 'Mușchiuleț de Vită cu Cartofi Wedges & Sparanghel'
          : (!isNoPork
              ? 'Somon Sălbatic la Cuptor cu Cartofi Copți & Salată'
              : 'Somon Sălbatic cu Cartofi Dulci & Legume Verzi'),
      calories: isCutting ? 600 : 740,
      proteinG: 50.0,
      carbsG: isCutting ? 45.0 : 65.0,
      fatG: 16.0,
      instructions: 'Coace somonul sau carnea la cuptor la 190°C. Pregătește cartofii la air-fryer cu mirodenii. Servește cu o salată verde mare.',
      ingredients: [
        RecipeIngredient(name: isBeefLover ? 'Mușchi de Vită Fraged' : 'Somon Sălbatic', amount: isCutting ? '200g' : '240g', state: 'raw'),
        RecipeIngredient(name: 'Cartofi / Cartofi Dulci', amount: isCutting ? '200g' : '300g', state: 'raw'),
        const RecipeIngredient(name: 'Sparanghel / Salată Verde', amount: '200g', state: 'frozen/raw'),
        const RecipeIngredient(name: 'Ulei de Măsline', amount: '5g', state: 'measured'),
      ],
    );
  }

  MealRecipe _createQuickSkilletRecipe(bool isCutting, bool isFishLover, bool isNoDairy) {
    return MealRecipe(
      id: '',
      category: 'LUNCH',
      title: isFishLover
          ? 'Tigaie Rapidă cu Somon & Orez Basmati (15 Min)'
          : 'Tigaie Rapidă Anabolică de Pui cu Orez & Legume (15 Min)',
      calories: isCutting ? 600 : 720,
      proteinG: 52.0,
      carbsG: isCutting ? 55.0 : 75.0,
      fatG: 12.0,
      instructions: 'Încinge 5g ulei de măsline într-o tigaie mare. Taie pieptul de pui cubulețe mici și gătește-l cu sare, piper și boia afumată timp de 5-6 minute. Adaugă legumele direct din congelator și sotează încă 4 minute. Servește cu orezul basmati fiert sau într-o lipie integrală!',
      ingredients: [
        RecipeIngredient(
          name: isFishLover ? 'Somon Sălbatic / Păstrăv' : 'Piept de Pui',
          amount: isCutting ? '220g' : '260g',
          state: 'raw',
        ),
        RecipeIngredient(
          name: 'Orez Basmati / Panzani',
          amount: isCutting ? '80g' : '110g',
          state: 'dry/uncooked',
        ),
        const RecipeIngredient(
          name: 'Legume Asortate (Broccoli / Fasole Verde)',
          amount: '200g',
          state: 'frozen/raw',
        ),
        const RecipeIngredient(
          name: 'Ulei de Măsline',
          amount: '5g',
          state: 'measured',
        ),
      ],
    );
  }

  String _generateOfflineChatResponse(
    String userMessage,
    UserProfile profile,
    Mission activeMission,
  ) {
    final lower = userMessage.toLowerCase().trim();
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

    final isExplicitEnglish = RegExp(r'\b(the|is|are|you|how|what|my|can|diet|meal|please|want|thanks|good|morning|evening)\b', caseSensitive: false).hasMatch(lower);
    final isRo = !isExplicitEnglish || RegExp(r'\b(salut|buna|bună|cf|ce faci|cum|esti|ești|vreau|fa|fă|retet|rețet|plan|mancare|mâncare|ce|ai|am|pot|sa|să|si|și|cine|pranz|prânz|mic|dejun|gustar|gustare|eticheta|etichet|poza|poză|somon|pui|orez|cartofi|oua|ouă|da|nu|multumesc|mersi|bine|super|grasimi|proteine|carbohidrati|slabit|masa|slabire)\b', caseSensitive: false).hasMatch(lower);

    // 1. Gratitude & Casual Feedback
    if (lower == 'mersi' ||
        lower == 'multumesc' ||
        lower == 'mulțumesc' ||
        lower == 'multam' ||
        lower.contains('super') ||
        lower.contains('arata bine') ||
        lower.contains('arată bine') ||
        lower.contains('perfect') ||
        lower.contains('top') ||
        lower.contains('tare')) {
      if (isRo) {
        return 'Cu cel mai mare drag, ${profile.firstName}! 🐼💪 Mă bucur mult că îți place și că te ajută!\n\nDacă vrei să schimbăm vreun ingredient, ai preferințe speciale sau găsești alimente noi prin magazin, trimite-mi o poză sau scrie-mi oricând. Facem o echipă de top!';
      } else {
        return 'Anytime, ${profile.firstName}! 🐼💪 Glad you love it! Whenever you want to swap ingredients or check new grocery items, just message me or send a photo!';
      }
    }

    // 2. Check-in ("cum esti" / "ce faci")
    if (lower.contains('cum esti') || lower.contains('cum ești') || lower.contains('ce faci') || lower.contains('how are you') || lower.contains('how r u')) {
      if (isRo) {
        return 'Sunt super bine și plin de energie, ${profile.firstName}! 🐼💪\n\nTu cum ești azi? Cum merge obiectivul de ${isCutting ? "Cutting" : "Bulking"}? Vrei o recomandare rapidă de masă (15 min), un plan complet pe o zi sau ai cumpărat ceva nou și vrei să-i verificăm eticheta? 📸';
      } else {
        return 'I am feeling great and energized, ${profile.firstName}! 🐼💪\n\nHow is your day going? Need a quick 15-min meal idea, a full day meal plan, or got a food label you want me to inspect? 📸';
      }
    }

    // 3. Greetings only (without other questions)
    if (lower == 'salut' || lower == 'buna' || lower == 'bună' || lower == 'hello' || lower == 'hi' || lower == 'hey' || lower == 'neata' || lower == 'neața') {
      if (isRo) {
        return 'Salut ${profile.firstName}! 👋 Mă bucur să te aud! Sunt gata să te ajut cu orice ai nevoie pentru obiectivul tău de **${isCutting ? "Cutting" : "Bulking"} (~$recommendedTarget kcal/zi)**.\n\nCe facem azi?\n⚡ **O recomandare rapidă de masă (15 min)**\n🍱 **Un plan alimentar complet pe o zi**\n📸 **O verificare de etichetă nutritivă**';
      } else {
        return 'Hey ${profile.firstName}! 👋 Great to see you! Ready to help you crush your **${isCutting ? "Cutting" : "Bulking"} goal (~$recommendedTarget kcal/day)**.\n\nWant a quick 15-min meal idea, a full daily plan, or have a label to check? 📸';
      }
    }

    // 4. Single Quick Meal Recommendation (10-15 min fast meal)
    if (isQuickOrSingleMealQuery(lower) &&
        !lower.contains('mic dejun') &&
        !lower.contains('breakfast') &&
        !lower.contains('cina') &&
        !lower.contains('cină') &&
        !lower.contains('gustar')) {
      if (isRo) {
        return '''
Sigur, ${profile.firstName}! 🐼⚡ Dacă ești pe fugă și vrei ceva gata în **maxim 12-15 minute**, hrănitor și adaptat perfect pentru **${isCutting ? "Cutting" : "Bulking"}**, îți recomand o **Tigaie Rapidă Anabolică de Pui cu Orez Basmati & Legume**.

💡 **De ce este ideală:**
• Se face într-o singură tigaie — minim de vase și efort!
• Îți oferă **~52g de proteine** curate pentru masă musculară și fibre din plin care țin foamea la distanță.

⚖️ **Gramaje exacte cântărite:**
• **220g Piept de pui** (cântărit **CRUD**, tăiat cubulețe subțiri să se facă rapid)
• **80g Orez Basmati** (cântărit **USCAT/crud**) fiert rapid sau o lipie integrală (wrap)
• **200g Legume asortate** (broccoli/fasole verde/ardei congelate)
• **5g Ulei de măsline** măsurat + sare, piper, boia afumată și oregano

🍳 **Cum o prepari rapid (12 min):**
1. Încingi tigaia cu cele 5g de ulei, adaugi cuburile de pui condimentate și le sotezi 5-6 minute până se rumenesc.
2. Răstorni legumele congelate peste pui și sotezi încă 4 minute la foc iute.
3. Servești cald alături de orez sau rulezi totul într-un wrap!

👇 **Ți-am atașat cardul rețetei chiar mai jos.** Apasă pe **„Salvează în Meniul Meu”** ca să o ai salvată instant în profilul tău și să o poți bifa în jurnal!''';
      } else {
        return '''
Sure, ${profile.firstName}! 🐼⚡ Here is a fast, 15-minute high-protein meal optimized for your **${isCutting ? "Cutting" : "Bulking"} goal**: a **15-Min Power Chicken & Veggie Skillet**.

⚖️ **Exact Weighed Portions:**
• **220g Chicken Breast** (weighed **RAW**, diced small)
• **80g Basmati Rice** (weighed **DRY/uncooked**) or whole wheat wrap
• **200g Mixed Veggies** (broccoli, green beans)
• **5g Olive Oil** (measured) + spices

👇 **I attached the recipe card right below.** Click **"Salvează în Meniul Meu"** to save it straight to your personal menu!''';
      }
    }

    // 5. Breakfast Request
    if (lower.contains('mic dejun') || lower.contains('micul dejun') || lower.contains('breakfast')) {
      if (isRo) {
        return '''
Uite o opțiune de top pentru micul dejun, ${profile.firstName}! 🍳

🥞 **Omletă Anabolică cu Legume Verzi & Toast Graham (~520 kcal | 42g Proteine)**:
• **3 Ouă întregi** (crude) bătute cu sare și piper, gătite în **5g ulei de măsline măsurat**.
• **100g Brânză Cottage Light 3%** pentru sațietate crescută și proteine cu eliberare lentă.
• **200g Legume verzi** (broccoli sau fasole verde) trase rapid la tigaie.
• **70g Pâine Graham** sau integrală cu maia.

👇 **Ți-am atașat cardul rețetei mai jos.** Apasă pe **„Salvează în Meniul Meu”** ca să o adaugi în planul tău!''';
      }
    }

    // 6. Dinner Request
    if (lower.contains('cina') || lower.contains('cină') || lower.contains('dinner')) {
      if (isRo) {
        return '''
Uite o cină ușoară, bogată în acizi grași Omega-3 și foarte sățioasă, ${profile.firstName}! 🐟🥗

🍽️ **Somon Sălbatic la Cuptor cu Cartofi Copți & Salată (~600 kcal | 50g Proteine)**:
• **200g Somon sălbatic sau Păstrăv** (cântărit **CRUD**) la cuptor la 190°C timp de 15 minute.
• **200g Cartofi** (cântăriți **CRUD**) tăiați wedges, condimentați cu boia și făcuți la air-fryer.
• O salată verde mare cu lămâie și **5g ulei de măsline măsurat**.

👇 **Apasă pe butonul de pe cardul de mai jos** pentru a salva această cină în meniul tău personal!''';
      }
    }

    // 7. Snack Request
    if (lower.contains('gustar') || lower.contains('snack')) {
      if (isRo) {
        return '''
Iată o gustare metabolică rapidă, dulce și plină de antioxidanți, ${profile.firstName}! 🍏

🫐 **Iaurt Grecesc cu Afine & Semințe Chia (~280 kcal | 22g Proteine)**:
• **150g Iaurt Grecesc 2%**.
• **75g Afine proaspete sau congelate**.
• **10g Semințe de chia** (pentru fibre și omega-3).
• **10g Unt de arahide 100%** (opțional, măsurat).

👇 **Cardul rețetei este chiar mai jos!** Apasă pe **„Salvează în Meniul Meu”** ca să o salvezi!''';
      }
    }

    // 8. Full Daily Meal Plan Request
    if (lower.contains('plan') ||
        lower.contains('meniu') ||
        lower.contains('menu') ||
        lower.contains('ce mananc') ||
        lower.contains('ce să mănânc') ||
        lower.contains('toate mesele') ||
        lower.contains('diet')) {
      if (isRo) {
        return '''
🔥 **Planul tău alimentar complet este gata, ${profile.firstName}!**

L-am configurat special pentru greutatea ta de **${profile.profileStartWeight} kg**, calibrat la **~$recommendedTarget kcal/zi** (${isCutting ? "CUTTING: -450 kcal deficit pentru ardere accelerată a grăsimilor" : "BULKING: +300 kcal surplus curat"}).

Fiecare masă conține proteine de calitate, carbohidrați complecși cu indice glicemic scăzut și legume voluminoase pentru sațietate maximă.

👇 **Găsești toate cele 4 mese configurate în detaliu pe cardurile interactive de mai jos!**
Poți salva fiecare masă individual în meniul tău sau poți apăsa direct pe **„Salvează Tot Planul”** pentru a le importa pe toate 4 dintr-un singur click în profilul tău!''';
      } else {
        return '''
🔥 **Your personalized daily meal plan is ready, ${profile.firstName}!**

Optimized for your weight of **${profile.profileStartWeight} kg**, calibrated to **~$recommendedTarget kcal/day** (${isCutting ? "CUTTING: -450 kcal fat loss deficit" : "BULKING: +300 kcal lean bulk surplus"}).

👇 **All 4 balanced meals are configured on the interactive cards below!**
You can save each meal individually or click **"Salvează Tot Planul"** to import all 4 at once into your personal menu!''';
      }
    }

    // 9. Protein questions
    if (lower.contains('proteina') || lower.contains('protein') || lower.contains('gram')) {
      final proteinTarget = (profile.profileStartWeight * 2.0).round();
      if (isRo) {
        return '''
🥩 **Necesarul tău optim de proteine:**
• Pentru greutatea ta de **${profile.profileStartWeight} kg**, ținta optimă este de **~$proteinTarget g proteine/zi** (~2.0g per kg corp).
• **Surse de top:** Piept de pui crud (23g P/100g), somon sălbatic (20g P/100g), ouă întregi (6g P/buc), iaurt grecesc 2% (10g P/100g), brânză cottage light (12g P/100g).''';
      } else {
        return '''
🥩 **Optimal Daily Protein Target:**
• For your profile (${profile.profileStartWeight} kg), aim for **~$proteinTarget g protein/day** (~2.0g per kg bodyweight).
• **Top sources:** Raw chicken breast (23g P/100g), wild salmon (20g P/100g), whole eggs (6g P/egg), 2% Greek yogurt (10g P/100g), light cottage cheese (12g P/100g).''';
      }
    }

    // 10. BMR / TDEE
    if (lower.contains('menten') || lower.contains('tdee') || lower.contains('bmr') || lower.contains('calor')) {
      if (isRo) {
        return '''
📊 **Profilul tău metabolic PandaFit:**
• **BMR (Consum bazal în repaus):** ~$bmr kcal/zi
• **TDEE (Mentenanță zilnică):** ~$maintenance kcal/zi
• **Target recomandat (${isCutting ? "Cutting" : "Bulking"}):** **~$recommendedTarget kcal/zi** (${isCutting ? "-450 kcal deficit pentru ardere grăsimi" : "+300 kcal surplus pentru masă musculară"}).''';
      } else {
        return '''
📊 **PandaFit Metabolic Profile:**
• **BMR (Basal Rest):** ~$bmr kcal/day
• **Maintenance (TDEE):** ~$maintenance kcal/day
• **Recommended Target (${isCutting ? "Cutting" : "Bulking"}):** **~$recommendedTarget kcal/day** (${isCutting ? "-450 kcal fat loss deficit" : "+300 kcal lean bulk surplus"}).''';
      }
    }

    // 11. Default friendly conversation
    if (isRo) {
      return 'Sunt aici alături de tine, ${profile.firstName}! 🐼💪 Spune-mi exact ce ai în minte: vrei o recomandare rapidă de masă (15 min), să punem la punct meniul pe azi sau ai o poză cu o etichetă pe care vrei să o analizăm?';
    }

    return 'I am right here with you, ${profile.firstName}! 🐼💪 Tell me what you need: a quick 15-min meal idea, a full day meal plan, or got a food label you want me to inspect?';
  }
}

