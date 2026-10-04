import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';

class NutritionGuideScreen extends StatelessWidget {
  const NutritionGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'NUTRITION & PROTOCOLS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: AppColors.emerald,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Glycemic Food Matrix',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),

              // Weighing Protocol Banner
              GlassCard(
                borderColor: AppColors.cyan.withValues(alpha: 0.4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.scale, color: AppColors.cyan, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Strict Weighing Protocol',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildProtocolItem('Meat / Poultry', 'Weigh in RAW / uncooked state (moisture loss varies).'),
                    _buildProtocolItem('Rice / Carbs', 'Weigh in DRY / uncooked state (e.g. 125g dry rice).'),
                    _buildProtocolItem('Vegetables', 'Weigh FROZEN / raw state for accurate glycemic fiber math.'),
                    _buildProtocolItem('Cooking Oils', 'Measured in grams/ml (never pour unmeasured).'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Meal Plans Accordion / Cards
              const Text(
                'Predefined Quick Meal Options',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),

              _buildMealCard(
                title: 'Breakfast: Standard Omelet & Greens',
                macros: '620 kcal · 42g P · 48g C · 26g F',
                ingredients: [
                  '3 whole eggs (whisked)',
                  '100g Cottage Cheese Light (3%)',
                  '200g Veggies (80g broccoli + 60g beans + 60g mushrooms)',
                  '70-80g Graham bread',
                  '5g measured Olive Oil',
                ],
              ),
              const SizedBox(height: 12),

              _buildMealCard(
                title: 'Snack: Greek Yogurt & Berry Bowl',
                macros: '240 kcal · 18g P · 18g C · 9.5g F',
                ingredients: [
                  '150g Greek Yogurt (2% fat)',
                  '75g fresh or frozen blueberries',
                  '10g Chia seeds',
                  '10g 100% natural peanut butter',
                ],
              ),
              const SizedBox(height: 12),

              _buildMealCard(
                title: 'Dinner Option A: Chicken Breast & Rice',
                macros: '780 kcal · 62g P · 105g C · 8g F',
                ingredients: [
                  '200-250g Chicken Breast (raw weighed)',
                  '125g Panzani / Basmati Rice (dry weighed)',
                  '250g Mixed Veggies (raw/frozen)',
                  '50-100g Pickles in brine',
                ],
              ),
              const SizedBox(height: 12),

              _buildMealCard(
                title: 'Dinner Option B: Pork Collar & High Veggies',
                macros: '540 kcal · 44g P · 20g C · 32g F',
                ingredients: [
                  '180-200g Pork Collar (raw weighed, no added oil)',
                  '300g Mixed Veggies (steamed or air-fried)',
                  '50-100g Pickles in brine',
                ],
              ),
              const SizedBox(height: 12),

              _buildMealCard(
                title: 'Dinner Option C: Chicken & Potato Wedges',
                macros: '610 kcal · 58g P · 48g C · 14g F',
                ingredients: [
                  '200-250g Chicken Breast (raw weighed)',
                  '200g Gustona Potato Wedges (air-fried)',
                  '50-100g Pickles in brine',
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProtocolItem(String label, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.emerald,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.3),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard({
    required String title,
    required String macros,
    required List<String> ingredients,
  }) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            macros,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.emeraldLight,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.surfaceElevated, height: 1),
          const SizedBox(height: 10),
          ...ingredients.map(
            (ing) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Text(
                '• $ing',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
