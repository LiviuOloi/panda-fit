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

  static const Map<String, String> _headers = {
    'User-Agent': 'PandaFit/1.0 (https://github.com/LiviuOloi/panda-fit; contact@pandafit.app)',
    'Accept': 'application/json',
  };

  /// Popular sample food products available in Romanian/European supermarkets for 1-click test
  static const List<DemoBarcodeItem> demoBarcodes = [
    DemoBarcodeItem(
      barcode: '5941014001234',
      name: 'Olympus Cottage Cheese Light',
      category: 'MIC DEJUN',
    ),
    DemoBarcodeItem(
      barcode: '3038350005400',
      name: 'Orez Basmati Panzani Express',
      category: 'CINĂ',
    ),
    DemoBarcodeItem(
      barcode: '5201051000282',
      name: 'Iaurt Grecesc 2% Olympus',
      category: 'GUSTARE',
    ),
    DemoBarcodeItem(
      barcode: '5941487002014',
      name: 'Fulgi de Ovăz Fin SanoVita',
      category: 'MIC DEJUN',
    ),
    DemoBarcodeItem(
      barcode: '8004030041006',
      name: 'Ton în Suc Propriu Rio Mare',
      category: 'CINĂ',
    ),
  ];

  Future<ScannedFoodProduct?> fetchProduct(String barcode) async {
    final cleanBarcode = barcode.replaceAll(RegExp(r'\s+|-'), '').trim();
    if (cleanBarcode.isEmpty || cleanBarcode.length < 6) {
      return null;
    }

    final endpoints = [
      'https://world.openfoodfacts.org/api/v2/product/$cleanBarcode.json',
      'https://ro.openfoodfacts.org/api/v2/product/$cleanBarcode.json',
    ];

    for (final url in endpoints) {
      try {
        final uri = Uri.parse(url);
        final response = await _client.get(uri, headers: _headers).timeout(
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
