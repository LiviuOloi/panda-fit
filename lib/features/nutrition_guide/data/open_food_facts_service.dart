import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../domain/scanned_food_product.dart';

class DemoBarcodeItem {
  final String barcode;
  final String name;
  final String category;

  const DemoBarcodeItem({
    required this.barcode,
    required this.name,
    required this.category,
  });
}

class OpenFoodFactsService {
  final http.Client _client;

  OpenFoodFactsService([http.Client? client]) : _client = client ?? http.Client();

  /// Popular sample food products with verified real barcodes from OpenFoodFacts
  static const List<DemoBarcodeItem> demoBarcodes = [
    DemoBarcodeItem(
      barcode: '5941875904169',
      name: 'Olympus Cottage Cheese Light',
      category: 'MIC DEJUN',
    ),
    DemoBarcodeItem(
      barcode: '5941875900413',
      name: 'Iaurt Grecesc 2% Olympus',
      category: 'GUSTARE',
    ),
    DemoBarcodeItem(
      barcode: '5411188110835',
      name: 'Băutură Migdale Alpro',
      category: 'GUSTARE',
    ),
    DemoBarcodeItem(
      barcode: '8410090031549',
      name: 'Ton în Suc Propriu',
      category: 'CINĂ',
    ),
    DemoBarcodeItem(
      barcode: '3017620422003',
      name: 'Nutella Ferrero',
      category: 'GUSTARE',
    ),
    DemoBarcodeItem(
      barcode: '5449000000439',
      name: 'Coca-Cola Original Taste',
      category: 'GUSTARE',
    ),
  ];

  /// Preloaded instant cache for demo barcodes to guarantee 100% instant offline response
  static final Map<String, ScannedFoodProduct> _cachedDemoProducts = {
    '5941875904169': const ScannedFoodProduct(
      barcode: '5941875904169',
      name: 'Cottage Cheese Light (2% Grăsime)',
      brand: 'Olympus',
      imageUrl: 'https://images.openfoodfacts.org/images/products/594/187/590/4169/front_ro.4.400.jpg',
      caloriesPer100g: 82,
      proteinPer100g: 12.0,
      carbsPer100g: 3.2,
      sugarsPer100g: 2.8,
      fatPer100g: 2.2,
      saturatedFatPer100g: 1.4,
      fiberPer100g: 0.0,
      nutriscoreGrade: 'A',
      ingredientsText: 'Lapte de vacă pasteurizat degresat, smântână pasteurizată, culturi lactice, sare.',
      servingSize: '150g',
    ),
    '5941875900413': const ScannedFoodProduct(
      barcode: '5941875900413',
      name: 'Iaurt Grecesc 2% Grăsime',
      brand: 'Olympus',
      imageUrl: 'https://images.openfoodfacts.org/images/products/594/187/590/0413/front_ro.10.400.jpg',
      caloriesPer100g: 66,
      proteinPer100g: 10.0,
      carbsPer100g: 4.0,
      sugarsPer100g: 4.0,
      fatPer100g: 2.0,
      saturatedFatPer100g: 1.3,
      fiberPer100g: 0.0,
      nutriscoreGrade: 'A',
      ingredientsText: 'Lapte de vacă pasteurizat, culturi lactice specifice de iaurt.',
      servingSize: '150g',
    ),
    '5411188110835': const ScannedFoodProduct(
      barcode: '5411188110835',
      name: 'Băutură de Migdale (Original)',
      brand: 'Alpro',
      imageUrl: 'https://images.openfoodfacts.org/images/products/541/118/811/0835/front_de.38.400.jpg',
      caloriesPer100g: 24,
      proteinPer100g: 0.5,
      carbsPer100g: 3.0,
      sugarsPer100g: 3.0,
      fatPer100g: 1.1,
      saturatedFatPer100g: 0.1,
      fiberPer100g: 0.4,
      nutriscoreGrade: 'B',
      ingredientsText: 'Apă, migdale (2.3%), zahăr, fosfat tricalcic, sare de mare, stabilizatori.',
      servingSize: '200ml',
    ),
    '8410090031549': const ScannedFoodProduct(
      barcode: '8410090031549',
      name: 'Ton Bucăți în Suc Propriu (Natural)',
      brand: 'Calvo',
      imageUrl: 'https://images.openfoodfacts.org/images/products/841/009/003/1549/front_es.12.400.jpg',
      caloriesPer100g: 76,
      proteinPer100g: 18.0,
      carbsPer100g: 0.0,
      sugarsPer100g: 0.0,
      fatPer100g: 0.6,
      saturatedFatPer100g: 0.2,
      fiberPer100g: 0.0,
      nutriscoreGrade: 'A',
      ingredientsText: 'Ton (Katsuwonus pelamis), apă, sare.',
      servingSize: '80g',
    ),
    '3017620422003': const ScannedFoodProduct(
      barcode: '3017620422003',
      name: 'Nutella Cremă de Alune cu Cacao',
      brand: 'Ferrero',
      imageUrl: 'https://images.openfoodfacts.org/images/products/301/762/042/2003/front_fr.464.400.jpg',
      caloriesPer100g: 539,
      proteinPer100g: 6.3,
      carbsPer100g: 57.5,
      sugarsPer100g: 56.3,
      fatPer100g: 30.9,
      saturatedFatPer100g: 10.6,
      fiberPer100g: 3.0,
      nutriscoreGrade: 'E',
      ingredientsText: 'Zahăr, ulei de palmier, alune de pădure (13%), lapte praf degresat (8.7%), cacao cu conținut redus de grăsime (7.4%).',
      servingSize: '15g',
    ),
    '5449000000439': const ScannedFoodProduct(
      barcode: '5449000000439',
      name: 'Coca-Cola Original Taste',
      brand: 'Coca-Cola',
      imageUrl: 'https://images.openfoodfacts.org/images/products/544/900/000/0439/front_fr.189.400.jpg',
      caloriesPer100g: 42,
      proteinPer100g: 0.0,
      carbsPer100g: 10.6,
      sugarsPer100g: 10.6,
      fatPer100g: 0.0,
      saturatedFatPer100g: 0.0,
      fiberPer100g: 0.0,
      nutriscoreGrade: 'E',
      ingredientsText: 'Apă, zahăr, dioxid de carbon, colorant caramel (E150d), acidifiant acid fosforic, arome naturale, cafeină.',
      servingSize: '250ml',
    ),
  };

  Future<ScannedFoodProduct?> fetchProduct(String barcode) async {
    final cleanBarcode = barcode.replaceAll(RegExp(r'\s+|-'), '').trim();
    if (cleanBarcode.isEmpty || cleanBarcode.length < 6) {
      return null;
    }

    // 1. Instant cache check for demo items
    if (_cachedDemoProducts.containsKey(cleanBarcode)) {
      return _cachedDemoProducts[cleanBarcode];
    }

    // 2. Fetch live from OpenFoodFacts universal JSON endpoints
    final endpoints = [
      'https://world.openfoodfacts.org/api/v0/product/$cleanBarcode.json',
      'https://ro.openfoodfacts.org/api/v0/product/$cleanBarcode.json',
      'https://world.openfoodfacts.net/api/v0/product/$cleanBarcode.json',
    ];

    final headers = kIsWeb
        ? <String, String>{'Accept': 'application/json'}
        : <String, String>{
            'User-Agent': 'PandaFit/1.0 (https://github.com/LiviuOloi/panda-fit; contact@pandafit.app)',
            'Accept': 'application/json',
          };

    for (final url in endpoints) {
      try {
        final uri = Uri.parse(url);
        final response = await _client.get(uri, headers: headers).timeout(
              const Duration(seconds: 8),
            );

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final status = data['status'];
          if (status == 1 && data['product'] != null) {
            final productMap = data['product'] as Map<String, dynamic>;
            return ScannedFoodProduct.fromOpenFoodFacts(cleanBarcode, productMap);
          }
        }
      } catch (e) {
        debugPrint('OpenFoodFacts fetch error for $cleanBarcode on $url: $e');
      }
    }

    return null;
  }
}
