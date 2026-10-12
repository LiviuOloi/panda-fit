import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:panda_fit/features/nutrition_guide/data/open_food_facts_service.dart';
import 'package:panda_fit/features/nutrition_guide/domain/scanned_food_product.dart';

void main() {
  group('ScannedFoodProduct & OpenFoodFacts Tests', () {
    test('ScannedFoodProduct parses OpenFoodFacts JSON and computes accurate portion macros', () {
      final mockProductData = {
        'product_name': 'Cottage Cheese Light 2%',
        'brands': 'Olympus',
        'image_front_url': 'https://images.openfoodfacts.org/front.jpg',
        'nutriscore_grade': 'a',
        'serving_size': '150g',
        'ingredients_text_ro': 'Lapte de vacă pasteurizat, culturi lactice, sare',
        'nutriments': {
          'energy-kcal_100g': 85,
          'proteins_100g': 12.0,
          'carbohydrates_100g': 3.2,
          'sugars_100g': 2.8,
          'fat_100g': 2.2,
          'saturated-fat_100g': 1.4,
          'fiber_100g': 0.0,
        },
      };

      final product = ScannedFoodProduct.fromOpenFoodFacts('5941014001234', mockProductData);

      expect(product.barcode, '5941014001234');
      expect(product.name, 'Cottage Cheese Light 2%');
      expect(product.brand, 'Olympus');
      expect(product.caloriesPer100g, 85);
      expect(product.proteinPer100g, 12.0);
      expect(product.carbsPer100g, 3.2);
      expect(product.fatPer100g, 2.2);
      expect(product.nutriscoreGrade, 'A');

      // Test portion scaling for 200g (double)
      expect(product.calculateCalories(200.0), 170);
      expect(product.calculateProtein(200.0), 24.0);
      expect(product.calculateCarbs(200.0), 6.4);
      expect(product.calculateSugars(200.0), 5.6);
      expect(product.calculateFat(200.0), 4.4);

      // Test conversion to MealRecipe
      final recipe = product.toMealRecipe(grams: 150.0, category: 'MIC DEJUN', userId: 'user-1');
      expect(recipe.title, 'Cottage Cheese Light 2% (Olympus)');
      expect(recipe.category, 'MIC DEJUN');
      expect(recipe.calories, 128); // 85 * 1.5 = 127.5 -> 128
      expect(recipe.proteinG, 18.0);
      expect(recipe.ingredients.first.amount, '150g');
    });

    test('OpenFoodFactsService fetches product successfully and sanitizes barcode string', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('5941014001234')) {
          return http.Response(
            '''
            {
              "status": 1,
              "product": {
                "product_name": "Olympus Cottage Cheese",
                "brands": "Olympus",
                "nutriscore_grade": "a",
                "nutriments": {
                  "energy-kcal_100g": 85,
                  "proteins_100g": 12.0,
                  "carbohydrates_100g": 3.0,
                  "fat_100g": 2.0
                }
              }
            }
            ''',
            200,
          );
        }
        return http.Response('{"status": 0}', 200);
      });

      final service = OpenFoodFactsService(mockClient);

      // Barcode with extra spaces and dashes
      final product = await service.fetchProduct(' 594-1014-001234 ');
      expect(product, isNotNull);
      expect(product!.name, 'Olympus Cottage Cheese');
      expect(product.barcode, '5941014001234');
      expect(product.caloriesPer100g, 85);
      expect(product.proteinPer100g, 12.0);

      // Barcode not found
      final notFound = await service.fetchProduct('000000000000');
      expect(notFound, isNull);

      // Empty or invalid short barcode returns null
      final invalid = await service.fetchProduct('123');
      expect(invalid, isNull);
    });

    test('Demo barcodes catalog provides valid pre-configured items', () {
      expect(OpenFoodFactsService.demoBarcodes.isNotEmpty, isTrue);
      for (final demo in OpenFoodFactsService.demoBarcodes) {
        expect(demo.barcode.length, greaterThanOrEqualTo(10));
        expect(demo.name.isNotEmpty, isTrue);
      }
    });
  });
}
