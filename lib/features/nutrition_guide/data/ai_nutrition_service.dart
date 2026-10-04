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

  static const List<String> _candidateModels = [
    'gemini-2.0-flash',
    'gemini-1.5-flash-latest',
    'gemini-1.5-flash',
    'gemini-2.0-flash-exp',
    'gemini-1.5-pro-latest',
    'gemini-1.5-pro',
    'gemini-pro',
  ];

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

    if (apiKey.isNotEmpty) {
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
${imageBytes != null ? "NOTE: An image of a food product or nutrition label is attached. Inspect its ingredients, macros per 100g, and construct customized recipes featuring or incorporating this product with precise weighed portions!" : ""}

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
You are Panda AI — an elite, conversational, and encouraging fitness coach and expert nutritionist for PandaFit.
You converse naturally, intelligently, and warmly, just like ChatGPT or a top personal trainer!

USER BIOMETRIC PROFILE:
- Name: ${profile.firstName}
- Age: ${profile.age} years old
- Sex: ${profile.sex}
- Height: ${profile.heightCm} cm
- Starting Weight: ${profile.profileStartWeight} kg
- Target Weight: ${activeMission.targetWeight} kg (${isCutting ? "CUTTING / Fat Loss (-450 kcal deficit)" : "BULKING / Lean Muscle (+300 kcal surplus)"})
- Basal Metabolic Rate (BMR): ~$bmr kcal/day
- Maintenance TDEE: ~$maintenance kcal/day
- Recommended Daily Caloric Target: ~$recommendedTarget kcal/day

PANDAFIT CORE INVARIANTS:
1. Weighing state: Meat is ALWAYS weighed RAW, Rice/Carbs DRY/uncooked, Veggies RAW/frozen, Oils measured.
2. Glycemic focus: Low GI carbs (Basmati/Panzani rice, oats, sweet potatoes), high fiber vegetables, lean protein.

HOW TO CONVERSE & ASSIST:
1. Natural & Fluent Persona: Be friendly, direct, energetic, and supportive. Use natural conversation (Romanian or English based on the user). Never sound like a rigid medical report.
2. Generating Meal Plans: If the user asks for a meal plan (e.g., "Fa-mi un plan alimentar"), create a full, delicious day of eating (Breakfast, Lunch, Dinner, Snacks) directly in your message with exact raw/dry gram portions, calories, macros, and practical prep steps.
3. Checking Nutrition Labels & Products (Vision):
   - When the user sends a photo of a food item or nutrition label:
   - Carefully read its ingredients and nutritional table (Calories, Protein, Carbs, Sugars, Fat, Saturated Fat, Fiber).
   - Give a clear, straightforward verdict: Is it good/healthy? Is it suitable for their current ${isCutting ? 'cutting' : 'bulking'} target (~$recommendedTarget kcal/day)?
   - Recommend the exact portion (in grams) to eat and how to incorporate it into their daily meal plan!
4. Multi-turn Memory: Keep track of the full ongoing conversation (if you previously created a plan and the user now sends product photos, validate whether those specific products fit into that meal plan).
5. Formatting: Use Markdown formatting (bolding, bullet points, clean spacing, emojis 🐼💪🥗🔥) so responses are effortless to read.
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
          if (response.text != null && response.text!.trim().isNotEmpty) {
            return response.text!;
          }
        } catch (e) {
          debugPrint('Gemini chatConsultation tried $modelName error: $e');
        }
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

    if (lower.contains('salut') || lower.contains('buna') || lower.contains('hello') || lower.contains('hi') || lower.contains('hey') || lower.startsWith('servus')) {
      return 'Hello ${profile.firstName}! 👋 How are you feeling today? I am here to help you with meal ideas, macronutrient balancing, or any fitness questions for your ${isCutting ? 'cutting' : 'bulking'} mission (~$recommendedTarget kcal/day). What is on your mind?';
    }

    if (lower.contains('menten') || lower.contains('tdee') || lower.contains('bmr') || lower.contains('calor')) {
      return '''
📊 **PandaFit Metabolic Breakdown:**
• **BMR (Basal Rest):** ~$bmr kcal/day
• **Maintenance (TDEE):** ~$maintenance kcal/day
• **Recommended Target (${activeMission.missionType.name.toUpperCase()}):** ~$recommendedTarget kcal/day ${isCutting ? '(-450 kcal fat loss deficit)' : '(+300 kcal lean bulk surplus)'}.''';
    }

    if (lower.contains('proteina') || lower.contains('protein') || lower.contains('gram')) {
      final proteinTarget = (profile.profileStartWeight * 2.0).round();
      return '''
🥩 **Optimal Protein Guideline:**
• For your profile (${profile.profileStartWeight} kg, ${isCutting ? 'Cutting' : 'Bulking'}), aim for **~$proteinTarget g protein/day** (~2.0g per kg of body weight).
• Great clean sources: Raw weighed chicken breast (23g P / 100g), wild salmon (20g P / 100g), whole eggs (6g P / egg), 2% Greek yogurt (10g P / 100g), and light cottage cheese.''';
    }

    if (lower.contains('dairy') || lower.contains('lactate') || lower.contains('lactoza') || lower.contains('lactose')) {
      return '🚫 **Dairy-Free / Lactose-Free Protocol:** I have excluded all dairy items. Your healthy fats and clean protein are sourced from whole eggs, wild salmon, lean meats, and avocado. Check out your tailored recipes below!';
    }

    if (lower.contains('peste') || lower.contains('fish') || lower.contains('somon') || lower.contains('salmon')) {
      return '🐟 **High-Fish & Salmon Protocol:** I have crafted meals rich in essential Omega-3 EPA/DHA fatty acids and lean protein using wild salmon and white fish. Check out your proposed meals below!';
    }

    if (lower.contains('cutting') || lower.contains('slabire') || lower.contains('deficit') || lower.contains('fat loss')) {
      return '🔥 **Cutting Plan Activated:** Your target is ~$recommendedTarget kcal/day (-450 kcal deficit). I have generated high-volume, fiber-rich meals with lean protein to maximize fullness and energy.';
    }

    if (lower.contains('bulking') || lower.contains('masa') || lower.contains('muscle') || lower.contains('surplus')) {
      return '🦁 **Lean Bulking Plan Activated:** Your target is ~$recommendedTarget kcal/day (+300 kcal controlled surplus) for clean muscular hypertrophy with minimal fat storage.';
    }

    if (lower.contains('quick') || lower.contains('15-min') || lower.contains('rapid') || lower.contains('fast')) {
      return '⚡ **Quick 15-Minute Meals:** High-speed recipes optimized for rapid prep, while strictly preserving raw-weighed precision and low-glycemic fiber volume!';
    }

    if (lower.contains('inlocui') || lower.contains('schimb') || lower.contains('replace') || lower.contains('substitut')) {
      return '''
🔄 **PandaFit Macro Equivalence Rules:**
• **100g Dry Rice (~350 kcal, 75g Carbs):** = ~350g Raw Sweet Potatoes = ~80g Dry Rolled Oats = ~130g Graham / Whole Wheat Bread.
• **200g Raw Chicken Breast (~220 kcal, 46g Protein):** = ~220g Fresh Salmon Fillet = ~200g Lean Beef Sirloin = ~230g Trout.
*All measurements must strictly adhere to raw/dry state protocol!*''';
    }

    return 'I am here with you, ${profile.firstName}! Whether you need nutrition coaching, meal suggestions, macro calculations, or motivation for your ${isCutting ? 'cutting' : 'bulking'} mission (~$recommendedTarget kcal/day), just let me know what you need!';
  }
}

