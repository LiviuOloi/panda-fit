import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/calculation_engine.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/panda_button.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../missions/domain/mission_model.dart';
import '../../profile/domain/profile_model.dart';
import '../data/ai_nutrition_service.dart';
import '../data/gemini_api_key_provider.dart';
import '../data/recipes_repository.dart';
import '../domain/recipe_model.dart';
import 'gemini_api_key_dialog.dart';

final recipesRepositoryProvider = Provider<RecipesRepository>((ref) {
  return RecipesRepository();
});

final allRecipesProvider = FutureProvider<List<MealRecipe>>((ref) async {
  final user = ref.watch(currentUserProvider);
  final repo = ref.watch(recipesRepositoryProvider);
  return await repo.fetchAllRecipes(user?.id);
});

class AiNutritionistScreen extends ConsumerStatefulWidget {
  final UserProfile profile;
  final Mission activeMission;

  const AiNutritionistScreen({
    super.key,
    required this.profile,
    required this.activeMission,
  });

  @override
  ConsumerState<AiNutritionistScreen> createState() => _AiNutritionistScreenState();
}

class _AiNutritionistScreenState extends ConsumerState<AiNutritionistScreen> {
  final _aiService = AiNutritionService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  static const _chatStorageKey = 'panda_eats_ai_chat_history_cache';
  static const _recipesStorageKey = 'panda_eats_ai_generated_recipes_cache';

  bool _isLoading = false;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  final List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawMsgs = prefs.getString(_chatStorageKey);
      final legacyRawRecipes = prefs.getString(_recipesStorageKey);

      if (rawMsgs != null) {
        final list = json.decode(rawMsgs) as List<dynamic>;
        if (list.isNotEmpty) {
          final loadedMessages = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          
          // Migrate legacy unattached recipes if any
          if (legacyRawRecipes != null && loadedMessages.isNotEmpty) {
            final decodedLegacy = json.decode(legacyRawRecipes) as List<dynamic>;
            if (decodedLegacy.isNotEmpty) {
              final lastAiIndex = loadedMessages.lastIndexWhere((m) => m['role'] == 'ai');
              if (lastAiIndex != -1 && loadedMessages[lastAiIndex]['recipes'] == null) {
                loadedMessages[lastAiIndex]['recipes'] = decodedLegacy;
              }
            }
          }

          setState(() {
            _messages.clear();
            _messages.addAll(loadedMessages);
          });
          return;
        }
      }
    } catch (_) {}

    _setDefaultWelcome();
  }

  void _setDefaultWelcome() {
    final isCutting = widget.activeMission.missionType == MissionType.cutting;
    final target = CalculationEngine.calculateRecommendedTargetCalories(
      weightKg: widget.profile.profileStartWeight,
      heightCm: widget.profile.heightCm,
      age: widget.profile.age,
      sex: widget.profile.sex,
      missionType: widget.activeMission.missionType.name,
    );

    setState(() {
      _messages.clear();
      _messages.add({
        'role': 'ai',
        'text': 'Hello ${widget.profile.firstName}! I am Panda Eats AI Coach 🐼.\n\nYour target is **~$target kcal/day** (${isCutting ? "Cutting Deficit" : "Bulking Surplus"}).\nHow can I help you optimize your meals today?',
      });
    });
    _saveChatHistory();
  }

  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chatStorageKey, json.encode(_messages));
    } catch (_) {}
  }

  void _startNewCleanChat() {
    _setDefaultWelcome();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Started a fresh clean chat session!'),
        backgroundColor: AppColors.emerald,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = file.name;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Scan Nutrition Label or Product 📸',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Take a clear photo of the nutrition facts table or ingredient label. Panda AI will extract macros and build customized meals!',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.3),
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_outlined, color: AppColors.emerald),
                ),
                title: const Text('Take Photo with Camera', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: const Text('Capture live food package or nutrition facts', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: AppColors.cyanLight),
                ),
                title: const Text('Upload from Gallery / Files', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: const Text('Select existing photo or screenshot', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = presetText ?? _textController.text.trim();
    final imageBytesToSend = _selectedImageBytes;
    if ((text.isEmpty && imageBytesToSend == null) || _isLoading) return;

    final promptText = text.isNotEmpty
        ? text
        : 'Please analyze this nutrition label image. Extract its macros per 100g, assess its glycemic quality, and calculate custom meal recipes fitting my goals.';

    _textController.clear();
    setState(() {
      _selectedImageBytes = null;
      _selectedImageName = null;
      _messages.add({
        'role': 'user',
        'text': promptText,
        if (imageBytesToSend != null) 'image_base64': base64Encode(imageBytesToSend),
      });
      _isLoading = true;
    });

    _scrollToBottom();
    await _saveChatHistory();

    final customApiKey = ref.read(geminiApiKeyProvider).valueOrNull;

    // Check if preset chips or explicit recipe cards are requested
    final shouldGenerateCards = presetText != null ||
        promptText.toLowerCase().contains('generate meal plan') ||
        promptText.toLowerCase().contains('retete') ||
        promptText.toLowerCase().contains('recipe cards');

    final history = _messages.map((m) => {'role': m['role'] as String, 'text': m['text'] as String}).toList();

    // Run conversational consultation and optional recipe generation in parallel
    final chatFuture = _aiService.chatConsultation(
      history: history,
      userMessage: promptText,
      profile: widget.profile,
      activeMission: widget.activeMission,
      customApiKey: customApiKey,
      imageBytes: imageBytesToSend,
    );

    final planFuture = shouldGenerateCards
        ? _aiService.generateCustomMealPlan(
            profile: widget.profile,
            activeMission: widget.activeMission,
            userPreferences: promptText,
            customApiKey: customApiKey,
            imageBytes: imageBytesToSend,
          )
        : Future.value(<MealRecipe>[]);

    final results = await Future.wait([chatFuture, planFuture]);
    final reply = results[0] as String;
    final generatedForThisMessage = results[1] as List<MealRecipe>;

    if (!mounted) return;

    setState(() {
      _messages.add({
        'role': 'ai',
        'text': reply,
        if (generatedForThisMessage.isNotEmpty)
          'recipes': generatedForThisMessage.map((r) => r.toJson()).toList(),
      });
      _isLoading = false;
    });

    _scrollToBottom();
    await _saveChatHistory();
  }

  Future<void> _saveRecipeToUserMenu(MealRecipe recipe) async {
    final user = ref.read(currentUserProvider);
    final userId = user?.id ?? widget.profile.id;

    final userRecipe = MealRecipe(
      id: '',
      userId: userId,
      category: recipe.category,
      title: recipe.title,
      ingredients: recipe.ingredients,
      calories: recipe.calories,
      proteinG: recipe.proteinG,
      carbsG: recipe.carbsG,
      fatG: recipe.fatG,
      instructions: recipe.instructions,
    );

    try {
      final repo = ref.read(recipesRepositoryProvider);
      await repo.createCustomRecipe(userRecipe);

      ref.invalidate(allRecipesProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${recipe.title}" saved to your personal menu!'),
          backgroundColor: AppColors.emerald,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving recipe: $e'),
          backgroundColor: AppColors.rose,
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openApiKeyDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => const GeminiApiKeyDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiKeyAsync = ref.watch(geminiApiKeyProvider);
    final hasApiKey = apiKeyAsync.valueOrNull != null && apiKeyAsync.valueOrNull!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.smart_toy_outlined, color: AppColors.emeraldLight, size: 22),
            SizedBox(width: 8),
            Text(
              'Panda Eats AI Coach',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary, size: 22),
            tooltip: 'Start Fresh Clean Chat',
            onPressed: _startNewCleanChat,
          ),
          IconButton(
            icon: Icon(
              Icons.key,
              color: hasApiKey ? AppColors.emerald : AppColors.amber,
              size: 22,
            ),
            tooltip: hasApiKey ? 'Gemini Live AI Active' : 'Setup Free Gemini Key',
            onPressed: _openApiKeyDialog,
          ),
        ],
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Chat Messages List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg['role'] == 'user';
                  final imageBase64 = msg['image_base64'] as String?;
                  final rawRecipes = msg['recipes'] as List<dynamic>?;
                  final recipes = (rawRecipes != null && rawRecipes.isNotEmpty)
                      ? rawRecipes
                          .map((r) => MealRecipe.fromJson(Map<String, dynamic>.from(r as Map)))
                          .toList()
                      : <MealRecipe>[];

                  return Column(
                    crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isUser ? AppColors.emerald : AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: isUser ? null : Border.all(color: AppColors.glassBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (imageBase64 != null) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    base64Decode(imageBase64),
                                    width: 180,
                                    height: 180,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                              Text(
                                msg['text'] as String,
                                style: TextStyle(
                                  color: isUser ? Colors.white : AppColors.textPrimary,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (recipes.isNotEmpty) ...[
                        _buildMessageRecipesSection(recipes),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              ),
            ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppColors.emerald))),
                    SizedBox(width: 10),
                    Text('Panda AI is analyzing macros & computing recipes...', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),

            // Selected Image Preview Banner
            if (_selectedImageBytes != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.emerald.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(
                        _selectedImageBytes!,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '📸 Nutrition Label Attached',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.emeraldLight),
                          ),
                          Text(
                            _selectedImageName ?? 'label_photo.jpg',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
                      tooltip: 'Remove Image',
                      onPressed: () {
                        setState(() {
                          _selectedImageBytes = null;
                          _selectedImageName = null;
                        });
                      },
                    ),
                  ],
                ),
              ),

            // Quick Prompt Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  _buildQuickChip('📊 Maintenance & TDEE Analysis'),
                  _buildQuickChip('🔥 Generate Cutting Plan'),
                  _buildQuickChip('🐟 High-Fish & Salmon Menu'),
                  _buildQuickChip('🚫 Dairy-Free / No Lactose'),
                  _buildQuickChip('⚡ Quick 15-Minute Meals'),
                ],
              ),
            ),

            // Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.glassBorder)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.camera_alt_outlined,
                      color: _selectedImageBytes != null ? AppColors.emeraldLight : AppColors.textSecondary,
                      size: 22,
                    ),
                    tooltip: 'Scan Nutrition Label / Product Photo',
                    onPressed: _showImageSourceDialog,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: _selectedImageBytes != null
                            ? 'Add instructions for this label (optional)...'
                            : 'Ask Panda AI or attach a label photo...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppColors.emerald),
                    onPressed: () => _sendMessage(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        label: Text(label),
        backgroundColor: AppColors.surfaceElevated,
        labelStyle: const TextStyle(color: AppColors.emeraldLight, fontSize: 12, fontWeight: FontWeight.w600),
        side: const BorderSide(color: AppColors.glassBorder),
        onPressed: () => _sendMessage(label),
      ),
    );
  }

  Widget _buildMessageRecipesSection(List<MealRecipe> recipes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Icon(Icons.restaurant_menu, color: AppColors.emeraldLight, size: 18),
              SizedBox(width: 8),
              Text(
                'AI Proposed Meals (Glycemic & Raw Weighed)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        ...recipes.map((r) => _buildRecipeProposalCard(r)),
      ],
    );
  }

  Widget _buildRecipeProposalCard(MealRecipe recipe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        borderColor: AppColors.emerald.withValues(alpha: 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    recipe.category,
                    style: const TextStyle(color: AppColors.emeraldLight, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${recipe.calories} kcal',
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              recipe.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              '${recipe.proteinG ?? 0}g P · ${recipe.carbsG ?? 0}g C · ${recipe.fatG ?? 0}g F',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.cyanLight),
            ),
            const SizedBox(height: 10),
            const Divider(color: AppColors.surfaceElevated, height: 1),
            const SizedBox(height: 10),
            ...recipe.ingredients.map(
              (i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  children: [
                    const Text('• ', style: TextStyle(color: AppColors.emerald)),
                    Text('${i.name}: ', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 13)),
                    Text('${i.amount} (${i.state})', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            PandaButton(
              label: 'Save to My Menu',
              icon: Icons.bookmark_add_outlined,
              variant: PandaButtonVariant.secondary,
              width: double.infinity,
              onPressed: () => _saveRecipeToUserMenu(recipe),
            ),
          ],
        ),
      ),
    );
  }
}
