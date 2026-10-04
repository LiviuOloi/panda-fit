import 'dart:convert';
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
You are Panda AI — an energetic, friendly, and expert fitness coach and nutritionist for PandaFit.
You converse naturally, casually, and intelligently, exactly like ChatGPT with a warm, motivating personal trainer vibe!

CRITICAL LANGUAGE RULE:
- If the user writes in Romanian (e.g., "salut", "cum esti", "fa-mi un plan", or any Romanian query), you MUST respond completely and fluently in ROMANIAN! Use natural, friendly, informal phrasing ("tu", "hai să facem", "arată super", etc.).
- If the user writes in English, respond in English.
- NEVER respond in robotic or formal English when addressed in Romanian.

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
1. Natural & Casual Persona: Be warm, direct, conversational, and energetic. Never sound like an automated robotic system. Talk like an expert gym buddy & nutritionist who cares.
2. Generating Meal Plans: If the user asks for a meal plan, layout a complete, mouth-watering daily menu (Breakfast, Lunch, Dinner, Snack) directly in the message with exact raw/dry gram portions, calories, macros, and prep steps.
3. Checking Nutrition Labels & Products (Vision):
   - When the user sends a photo of a food item or nutrition label:
   - Carefully read its ingredients and nutritional table (Calories, Protein, Carbs, Sugars, Fat, Saturated Fat, Fiber).
   - Give a clear, friendly verdict: Is it good/healthy? Is it suitable for their current ${isCutting ? 'cutting' : 'bulking'} target (~$recommendedTarget kcal/day)?
   - Recommend the exact portion (in grams) to eat and how to incorporate it into their daily meal plan!
4. Multi-turn Memory: Keep track of the full ongoing conversation (if you previously created a plan and the user now sends product photos, validate whether those specific products fit into that meal plan).
5. Formatting: Use clean Markdown formatting (bolding, bullet points, clean spacing, emojis 🐼💪🥗🔥).
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
          try {
            final fallbackTurns = <Content>[
              Content.text('Instructions & Profile:\n$dynamicSystemPrompt'),
              ...validTurns,
            ];
            final model = GenerativeModel(model: modelName, apiKey: apiKey);
            final response = await model.generateContent(fallbackTurns);
            if (response.text != null && response.text!.trim().isNotEmpty) {
              return response.text!;
            }
          } catch (e2) {
            debugPrint('Gemini fallback chat error on $modelName: $e2');
          }
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

    return [
      MealRecipe(
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
      ),
      MealRecipe(
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
      ),
      MealRecipe(
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
      ),
      MealRecipe(
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
      ),
    ];
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

    // Detect Romanian (or default to Romanian if not strictly English text)
    final isExplicitEnglish = RegExp(r'\b(the|is|are|you|how|what|my|can|diet|meal|please|want|thanks|good|morning|evening)\b', caseSensitive: false).hasMatch(lower);
    final isRo = !isExplicitEnglish || RegExp(r'\b(salut|buna|bună|cf|ce faci|cum|esti|ești|vreau|fa|fă|retet|rețet|plan|mancare|mâncare|ce|ai|am|pot|sa|să|si|și|cine|pranz|prânz|mic|dejun|gustar|gustare|eticheta|etichet|poza|poză|somon|pui|orez|cartofi|oua|ouă|da|nu|multumesc|mersi|bine|super|grasimi|proteine|carbohidrati|slabit|masa|slabire)\b', caseSensitive: false).hasMatch(lower);

    // 1. "cum esti" / "ce faci"
    if (lower.contains('cum esti') || lower.contains('cum ești') || lower.contains('ce faci') || lower.contains('how are you') || lower.contains('how r u')) {
      if (isRo) {
        return 'Sunt super bine și plin de energie, ${profile.firstName}! 🐼💪\n\nTu cum te simți azi? Ai apucat să mănânci ceva sau vrei să punem la punct meniul pe ziua de azi? Dacă ai cumpărat produse noi, trimite-mi o poză cu eticheta și le integrăm imediat!';
      } else {
        return 'I am feeling great and energized, ${profile.firstName}! 🐼💪\n\nHow are you feeling today? Have you eaten yet or shall we map out your meals for today? If you have new groceries, snap a photo of the nutrition label and we will fit it in!';
      }
    }

    // 2. Greetings
    if (lower.contains('salut') || lower.contains('buna') || lower.contains('bună') || lower.contains('hello') || lower.contains('hi') || lower.contains('hey') || lower.contains('neata') || lower.contains('neața')) {
      if (isRo) {
        return 'Salut ${profile.firstName}! 👋 Mă bucur să te aud! Sunt gata să te ajut cu orice ai nevoie pentru obiectivul tău de **${isCutting ? "Cutting" : "Bulking"} (~$recommendedTarget kcal/zi)**.\n\nVrei un plan alimentar complet, o recomandare rapidă de masă sau ai vreo poză cu eticheta unui produs pe care vrei să o verificăm? 📸';
      } else {
        return 'Hey ${profile.firstName}! 👋 Great to see you! Ready to help you crush your **${isCutting ? "Cutting" : "Bulking"} goal (~$recommendedTarget kcal/day)**.\n\nWant a full daily meal plan, quick food tips, or got a photo of a food label you want me to inspect? 📸';
      }
    }

    // 3. Meal Plan Request
    if (lower.contains('plan') || lower.contains('meniu') || lower.contains('menu') || lower.contains('ce mananc') || lower.contains('ce să mănânc') || lower.contains('diet') || lower.contains('masa') || lower.contains('mâncare')) {
      if (isRo) {
        return '''
🔥 **Uite un Plan Alimentar Complet & Delicios — ${isCutting ? "CUTTING (-450 kcal deficit)" : "BULKING (+300 kcal surplus)"} (~$recommendedTarget kcal/zi):**

🍳 **1. Micul Dejun (~520 kcal | 42g P · 40g C · 18g F):**
• **3 Ouă întregi** (cântărite crude) omletă cu 5g ulei de măsline măsurat.
• **100g Brânză Cottage Light 3%** + **200g Legume verzi** (broccoli sau fasole verde).
• **70g Pâine Graham** sau integrală cu maia.

🍏 **2. Gustare Rapidă (~280 kcal | 22g P · 28g C · 8g F):**
• **150g Iaurt Grecesc 2%** + **75g Afine** + **10g Semințe chia**.

🍗 **3. Prânz Anabolic (~650 kcal | 55g P · 65g C · 12g F):**
• **220g Piept de pui** (cântărit **CRUD**).
• **100g Orez Basmati / Panzani** (cântărit **USCAT/crud**).
• **250g Legume asortate** trase la tigaie + **80g Murături în saramură**.

🥗 **4. Cină Ușoară (~600 kcal | 50g P · 45g C · 16g F):**
• **200g Somon sălbatic sau Păstrăv** (cântărit **CRUD**) la cuptor.
• **200g Cartofi wedges / copți** (cântăriți **CRUD**) + salată mare verde.

---
📸 **Ce ai prin frigider sau cămară?** Trimite-mi poze cu etichetele produselor tale și îți zic pe loc dacă sunt bune și exact câte grame să pui pe cântar!''';
      } else {
        return '''
🔥 **Full Personalized Daily Meal Plan — ${isCutting ? "CUTTING (-450 kcal deficit)" : "BULKING (+300 kcal surplus)"} (~$recommendedTarget kcal/day):**

🍳 **1. High-Protein Breakfast (~520 kcal | 42g P · 40g C · 18g F):**
• **3 Whole eggs** (raw) cooked in 5g measured olive oil.
• **100g Cottage Cheese Light 3%** + **200g Green veggies** (broccoli/beans).
• **70g Graham or whole wheat toast**.

🍏 **2. Metabolic Snack (~280 kcal | 22g P · 28g C · 8g F):**
• **150g Greek Yogurt 2%** + **75g Blueberries** + **10g Chia seeds**.

🍗 **3. Power Lunch (~650 kcal | 55g P · 65g C · 12g F):**
• **220g Chicken Breast** (weighed **RAW**).
• **100g Basmati Rice** (weighed **DRY/uncooked**).
• **250g Mixed veggies** + **80g Pickles in brine**.

🥗 **4. Clean Dinner (~600 kcal | 50g P · 45g C · 16g F):**
• **200g Wild Salmon or Trout** (weighed **RAW**) oven-baked.
• **200g Raw-weighed potato wedges** + large leafy green salad.

---
📸 **Got food items at home?** Take photos of their nutrition facts labels and I will tell you if they fit and exact gram portions!''';
      }
    }

    // 4. Protein questions
    if (lower.contains('proteina') || lower.contains('protein') || lower.contains('gram')) {
      final proteinTarget = (profile.profileStartWeight * 2.0).round();
      if (isRo) {
        return '''
🥩 **Necesarul tău optim de proteine:**
• Pentru greutatea ta de **${profile.profileStartWeight} kg**, ținta ideală este de **~$proteinTarget g proteine/zi** (~2.0g per kg corp).
• **Surse de top:** Piept de pui crud (23g P/100g), somon sălbatic (20g P/100g), ouă întregi (6g P/buc), iaurt grecesc 2% (10g P/100g), brânză cottage light (12g P/100g).''';
      } else {
        return '''
🥩 **Optimal Daily Protein Target:**
• For your profile (${profile.profileStartWeight} kg), aim for **~$proteinTarget g protein/day** (~2.0g per kg bodyweight).
• **Top sources:** Raw chicken breast (23g P/100g), wild salmon (20g P/100g), whole eggs (6g P/egg), 2% Greek yogurt (10g P/100g), light cottage cheese (12g P/100g).''';
      }
    }

    // 5. BMR / TDEE
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

    // 6. Default friendly chat
    if (isRo) {
      return 'Sunt aici alături de tine, ${profile.firstName}! 💪 Spune-mi ce vrei să facem: vrei să stabilim un plan alimentar, sfaturi de macronutrienți sau ai o etichetă de produs pe care vrei să o verificăm împreună?';
    }

    return 'I am right here with you, ${profile.firstName}! 💪 Let me know what you want to work on: need a personalized meal plan, macro breakdown, or got a food label you want me to inspect for you?';
  }
}

