import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/panda_button.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/open_food_facts_service.dart';
import '../domain/recipe_model.dart';
import '../domain/scanned_food_product.dart';
import 'ai_nutritionist_screen.dart';

class BarcodeScannerDialog extends ConsumerStatefulWidget {
  final void Function(String aiPrompt)? onConsultAi;
  final void Function(MealRecipe recipe)? onRecipeSaved;

  const BarcodeScannerDialog({
    super.key,
    this.onConsultAi,
    this.onRecipeSaved,
  });

  static Future<void> show(
    BuildContext context, {
    void Function(String aiPrompt)? onConsultAi,
    void Function(MealRecipe recipe)? onRecipeSaved,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BarcodeScannerDialog(
        onConsultAi: onConsultAi,
        onRecipeSaved: onRecipeSaved,
      ),
    );
  }

  @override
  ConsumerState<BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends ConsumerState<BarcodeScannerDialog> {
  final _service = OpenFoodFactsService();
  final _manualCodeController = TextEditingController();
  MobileScannerController? _scannerController;

  bool _isCameraMode = true;
  bool _isLoading = false;
  String? _errorMessage;
  ScannedFoodProduct? _scannedProduct;
  double _portionGrams = 100.0;
  String _selectedCategory = 'GUSTARE';
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _initScanner();
  }

  void _initScanner() {
    try {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      );
    } catch (_) {
      _isCameraMode = false;
    }
  }

  @override
  void dispose() {
    _manualCodeController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _fetchBarcode(String barcode) async {
    if (_isLoading) return;
    final clean = barcode.trim();
    if (clean.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final product = await _service.fetchProduct(clean);
      if (!mounted) return;

      if (product != null) {
        setState(() {
          _scannedProduct = product;
          _isLoading = false;
          _portionGrams = 100.0;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Produsul cu codul "$clean" nu a fost găsit în baza OpenFoodFacts.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Eroare la căutare: $e';
      });
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_hasScanned || _isLoading || _scannedProduct != null) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.length >= 6) {
        _hasScanned = true;
        HapticFeedback.mediumImpact();
        _fetchBarcode(raw);
        break;
      }
    }
  }

  Color _getNutriScoreColor(String? grade) {
    switch (grade?.toUpperCase()) {
      case 'A':
        return const Color(0xFF038141);
      case 'B':
        return const Color(0xFF85BB2F);
      case 'C':
        return const Color(0xFFFECB02);
      case 'D':
        return const Color(0xFFEE8100);
      case 'E':
        return const Color(0xFFE63E11);
      default:
        return AppColors.textMuted;
    }
  }

  Future<void> _saveToPersonalMenu() async {
    final product = _scannedProduct;
    if (product == null) return;

    final user = ref.read(currentUserProvider);
    final recipe = product.toMealRecipe(
      grams: _portionGrams,
      category: _selectedCategory,
      userId: user?.id,
    );

    try {
      final repo = ref.read(recipesRepositoryProvider);
      await repo.createCustomRecipe(recipe);

      ref.invalidate(allRecipesProvider);

      if (!mounted) return;

      widget.onRecipeSaved?.call(recipe);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${recipe.title}" (${_portionGrams.round()}g) a fost salvat în Meniul Personal! 🐼'),
          backgroundColor: AppColors.emerald,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Eroare la salvare: $e'),
          backgroundColor: AppColors.rose,
        ),
      );
    }
  }

  void _consultPandaAi() {
    final product = _scannedProduct;
    if (product == null) return;

    final brandStr = product.brand != null ? ' (${product.brand})' : '';
    final prompt =
        'Am scanat produsul "${product.name}"$brandStr (cod: ${product.barcode}).\n'
        'Valori nutriționale per 100g:\n'
        '• Calorii: ${product.caloriesPer100g} kcal\n'
        '• Proteine: ${product.proteinPer100g}g\n'
        '• Carbohidrați: ${product.carbsPer100g}g (din care zaharuri: ${product.sugarsPer100g}g)\n'
        '• Grăsimi: ${product.fatPer100g}g (saturate: ${product.saturatedFatPer100g}g)\n'
        '• Fibre: ${product.fiberPer100g}g\n'
        '${product.nutriscoreGrade != null ? "• NutriScore: ${product.nutriscoreGrade}\n" : ""}'
        'Ce părere ai despre calitatea acestui produs pentru obiectivul meu actual? E bun în dietă și ce porție exactă în grame îmi recomanzi să mănânc?';

    Navigator.pop(context);
    widget.onConsultAi?.call(prompt);
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.glassBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code_scanner, color: AppColors.emeraldLight, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Scaner Alimente & Coduri',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(color: AppColors.surfaceElevated, height: 1),

          Expanded(
            child: _scannedProduct != null
                ? _buildProductInspector()
                : _buildScannerAndManualView(),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerAndManualView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mode Toggle Pills
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isCameraMode = true;
                        _hasScanned = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _isCameraMode ? AppColors.emerald : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined, size: 16, color: _isCameraMode ? Colors.white : AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Scanare Cameră',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _isCameraMode ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isCameraMode = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !_isCameraMode ? AppColors.emerald : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.keyboard_outlined, size: 16, color: !_isCameraMode ? Colors.white : AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Introducere Cod',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: !_isCameraMode ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(28),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.emerald)),
                  SizedBox(height: 16),
                  Text(
                    'Căutăm în baza oficială OpenFoodFacts... 🔍',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            )
          else if (_isCameraMode) ...[
            // Camera Viewport
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 240,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.emerald.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_scannerController != null)
                      MobileScanner(
                        controller: _scannerController!,
                        onDetect: _onBarcodeDetected,
                        errorBuilder: (ctx, err) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Camera nu a putut fi pornită.\nFolosește opțiunea „Introducere Cod”.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                            ),
                          );
                        },
                      ),
                    // Visual Target Frame
                    Center(
                      child: Container(
                        width: 200,
                        height: 140,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.emeraldLight, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Îndreaptă camera către codul de bare de pe ambalaj',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ] else ...[
            // Manual Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualCodeController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Ex: 5941014001234',
                      hintStyle: const TextStyle(color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.qr_code, color: AppColors.emeraldLight, size: 20),
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onSubmitted: (val) => _fetchBarcode(val),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onPressed: () => _fetchBarcode(_manualCodeController.text),
                  child: const Text('Caută', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],

          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.rose.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.rose, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.rose, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Quick Demo Barcode Chips for instant 1-click test
          const Text(
            'Testează rapid cu produse populare din RO/UE:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: OpenFoodFactsService.demoBarcodes.map((item) {
              return ActionChip(
                label: Text(item.name),
                avatar: const Icon(Icons.shopping_bag_outlined, size: 14, color: AppColors.emeraldLight),
                backgroundColor: AppColors.surfaceElevated,
                labelStyle: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                side: const BorderSide(color: AppColors.glassBorder),
                onPressed: () {
                  _manualCodeController.text = item.barcode;
                  _fetchBarcode(item.barcode);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildProductInspector() {
    final product = _scannedProduct!;
    final cal = product.calculateCalories(_portionGrams);
    final prot = product.calculateProtein(_portionGrams);
    final carbs = product.calculateCarbs(_portionGrams);
    final sugars = product.calculateSugars(_portionGrams);
    final fat = product.calculateFat(_portionGrams);
    final fiber = product.calculateFiber(_portionGrams);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Product Header Card
          GlassCard(
            borderColor: AppColors.emerald.withValues(alpha: 0.3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      product.imageUrl!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 64,
                        height: 64,
                        color: AppColors.surfaceElevated,
                        child: const Icon(Icons.fastfood_outlined, color: AppColors.textMuted),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.fastfood_outlined, color: AppColors.emeraldLight, size: 28),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (product.brand != null)
                        Text(
                          product.brand!.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.emeraldLight,
                            letterSpacing: 0.5,
                          ),
                        ),
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Cod: ${product.barcode}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                          if (product.nutriscoreGrade != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getNutriScoreColor(product.nutriscoreGrade),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Nutri-Score ${product.nutriscoreGrade}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Portion Weigher Section
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Porție Cântărită Exact (Grame):',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Text(
                      '${_portionGrams.round()} g',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.emeraldLight,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _portionGrams.clamp(10.0, 500.0),
                  min: 10.0,
                  max: 500.0,
                  divisions: 49,
                  activeColor: AppColors.emerald,
                  inactiveColor: AppColors.surface,
                  onChanged: (val) {
                    setState(() {
                      _portionGrams = (val / 5).round() * 5.0;
                    });
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [50.0, 100.0, 150.0, 200.0, 250.0].map((g) {
                    final isSel = _portionGrams == g;
                    return InkWell(
                      onTap: () => setState(() => _portionGrams = g),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.emerald : AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSel ? AppColors.emerald : AppColors.glassBorder),
                        ),
                        child: Text(
                          '${g.round()}g',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSel ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Live Macro Grid
          Row(
            children: [
              Expanded(
                child: _buildMacroCard('Calorii', '$cal', 'kcal', AppColors.amber),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMacroCard('Proteine', '$prot', 'g', AppColors.cyanLight),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMacroCard('Carbohidrați', '$carbs', 'g ($sugars g zahăr)', AppColors.emeraldLight),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMacroCard('Grăsimi', '$fat', 'g', Colors.orangeAccent),
              ),
            ],
          ),

          if (fiber > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.eco_outlined, size: 14, color: AppColors.emeraldLight),
                  const SizedBox(width: 6),
                  Text(
                    'Fibre alimentare: $fiber g per ${_portionGrams.round()}g',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),

          // Category Selector for Saving
          Row(
            children: [
              const Text('Categorie Meniu: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedCategory,
                dropdownColor: AppColors.surfaceElevated,
                style: const TextStyle(color: AppColors.emeraldLight, fontSize: 13, fontWeight: FontWeight.bold),
                underline: const SizedBox(),
                items: ['MIC DEJUN', 'GUSTARE', 'CINĂ', 'CUSTOM'].map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Action Buttons: Ask Panda AI vs Save
          PandaButton(
            label: 'Cere Părerea lui Panda AI 🐼',
            icon: Icons.smart_toy_outlined,
            variant: PandaButtonVariant.secondary,
            width: double.infinity,
            onPressed: _consultPandaAi,
          ),

          const SizedBox(height: 10),

          PandaButton(
            label: 'Salvează în Meniul Personal',
            icon: Icons.bookmark_add_outlined,
            width: double.infinity,
            onPressed: _saveToPersonalMenu,
          ),

          const SizedBox(height: 10),

          TextButton.icon(
            icon: const Icon(Icons.qr_code_scanner, size: 16, color: AppColors.textMuted),
            label: const Text('Scanează alt produs', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            onPressed: () {
              setState(() {
                _scannedProduct = null;
                _hasScanned = false;
                _errorMessage = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCard(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            unit,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
