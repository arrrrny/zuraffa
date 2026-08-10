import 'package:flutter/foundation.dart';

import '../data/grocery_dictionary.dart';
import '../data/stores_catalog.dart';
import '../models/detections.dart';
import '../models/grocery_item.dart';
import '../models/ingredients_analysis.dart';
import '../models/store_offer.dart';

/// MockProvider for the standalone UI/UX demo.
///
/// Everything the camera experience needs — location permission, text
/// detection, object detection and price comparison — is simulated here with
/// realistic latencies so the animation/UX timing can be iterated on. No
/// camera, no ML Kit, no backend required.
///
/// Simulated timings:
/// - location permission … ~1.4 s
/// - text detection ……… ~0.9 s
/// - object detection …… ~0.7 s
/// - price comparison ……… ~2.2 s  (spec: price revealed "within 3 seconds")
class MockGroceryProvider extends ChangeNotifier {
  MockGroceryProvider({this.locale = GroceryDictionary.defaultLocale});

  /// Active locale of the embedded dictionary (e.g. `en-US`, `tr-TR`).
  String locale;

  bool _locationGranted = false;
  bool get isLocationGranted => _locationGranted;

  /// Demo area label, surfaced in the location chip ("Mountain View, CA").
  String get locationLabel => locale == 'tr-TR' ? 'İstanbul, Türkiye' : 'Mountain View, CA';

  int _scanCounter = 0;

  // ---------------------------------------------------------------------------
  // Location permission
  // ---------------------------------------------------------------------------

  Future<bool> requestLocationPermission() async {
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    _locationGranted = true;
    notifyListeners();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Text detection (ML Kit text scanner, mocked)
  // ---------------------------------------------------------------------------

  /// Returns the text blocks found in the current "camera frame".
  ///
  /// The shelf tag reads "Heirloom Tomatoes" — the largest single text block —
  /// surrounded by smaller tag copy, exactly like a real in-store product tag.
  Future<TextDetectionResult> scanText() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return TextDetectionResult(
      primary: const TextBlock(text: 'Heirloom Tomatoes', confidence: 0.97),
      blocks: const [
        TextBlock(text: 'Heirloom Tomatoes', confidence: 0.97),
        TextBlock(text: 'Certified Organic', confidence: 0.88),
        TextBlock(text: 'Product of USA · Net Wt 1 lb', confidence: 0.76),
      ],
    );
  }

  /// Resolves a detected text block into an exact dictionary item.
  ///
  /// The product key found on the tag is used verbatim: text on a tag is
  /// authoritative (e.g. "Heirloom Tomatoes"), so no variant prompt is needed.
  GroceryItem itemFromText(TextBlock block) {
    final key =
        GroceryDictionary.resolveKey(locale, block.text, defaultKey: 'tomato');
    final variants = GroceryDictionary.variantsFor(locale, key!);
    // Prefer the variant that matches the detected text verbatim.
    for (final v in variants) {
      if (v.name.toLowerCase() == block.text.toLowerCase()) return v;
    }
    return variants.first;
  }

  // ---------------------------------------------------------------------------
  // Object detection (ML Kit object detector, mocked)
  // ---------------------------------------------------------------------------

  /// Scans whatever object is currently framed in the mock camera scene.
  ///
  /// Produce and meat can run DIFFERENT detection models, so the category is
  /// passed explicitly; [demoIndex] cycles the demo objects per category
  /// (produce: tomato → cantaloupe → avocado, meat: steak → chicken) so the
  /// variant edge case (cantaloupe has none) can be demonstrated.
  Future<ObjectDetectionResult> scanObject({
    required GroceryCategory category,
    required int demoIndex,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final (key, confidence) = switch (category) {
      GroceryCategory.produce => switch (demoIndex % 3) {
          0 => ('tomato', 0.94),
          1 => ('cantaloupe', 0.91),
          _ => ('avocado', 0.89),
        },
      GroceryCategory.meat => switch (demoIndex % 2) {
          0 => ('steak', 0.93),
          _ => ('chicken', 0.87),
        },
      _ => ('tomato', 0.94),
    };
    final variants = GroceryDictionary.variantsFor(locale, key);
    final item = variants.first; // conventional baseline
    return ObjectDetectionResult(item: item, confidence: confidence);
  }

  /// Variants the customer can confirm between after an object detection.
  ///
  /// Returns one item when the dictionary has no alternatives — the caller
  /// then skips the chooser entirely (spec: "if there is no other variation of
  /// cantaloupe it will not prompt").
  List<GroceryItem> variantsFor(GroceryItem detected) {
    // The conventional baseline is first in the dictionary; find its key by
    // re-resolving the name and return every display variant.
    final key =
        GroceryDictionary.resolveKey(locale, detected.name, defaultKey: 'tomato');
    return GroceryDictionary.variantsFor(locale, key!);
  }

  // ---------------------------------------------------------------------------
  // Price comparison
  // ---------------------------------------------------------------------------

  /// Compares the item across nearby stores, returning ranked offers.
  Future<List<StoreOffer>> comparePrices(GroceryItem item) async {
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    _scanCounter++;
    final offers = StoresCatalog.offersForItem('${item.id}#$_scanCounter');
    // Rank cheapest first and flag the best price.
    offers.sort((a, b) => a.price.compareTo(b.price));
    for (var i = 0; i < offers.length; i++) {
      offers[i] = StoreOffer(
        brand: offers[i].brand,
        price: offers[i].price,
        distanceMiles: offers[i].distanceMiles,
        inStore: offers[i].inStore,
        isBestPrice: i == 0,
      );
    }
    return offers;
  }

  // ---------------------------------------------------------------------------
  // Ingredient check (stethoscope mode — AI-backed when wired)
  // ---------------------------------------------------------------------------

  /// Captures the ingredient list and returns the gluten verdict + nutrition
  /// score. Mocked here; the real wiring reuses the ZikZakScore AI call
  /// (extract full text → one request → verdict + score).
  Future<IngredientsAnalysis> scanIngredients() async {
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    return const IngredientsAnalysis(
      productName: 'Honey Oat Granola',
      brand: 'Morning Harvest',
      verdict: GlutenVerdict.contains,
      nutritionScore: 62,
      factors: [
        NutritionFactor(
          label: 'Sugar',
          value: '9g',
          score: 34,
          isBeneficial: false,
        ),
        NutritionFactor(
          label: 'Saturated fat',
          value: '2.1g',
          score: 58,
          isBeneficial: false,
        ),
        NutritionFactor(
          label: 'Sodium',
          value: '95mg',
          score: 72,
          isBeneficial: false,
        ),
        NutritionFactor(
          label: 'Protein',
          value: '8g',
          score: 76,
          isBeneficial: true,
        ),
        NutritionFactor(
          label: 'Fiber',
          value: '5g',
          score: 84,
          isBeneficial: true,
        ),
      ],
      ingredients: [
        'Whole Grain Oats',
        'Wheat Flour',
        'Honey',
        'Canola Oil',
        'Brown Sugar',
        'Barley Malt',
        'Sea Salt',
        'Cinnamon',
      ],
      glutenSources: ['Wheat Flour', 'Barley Malt', 'Whole Grain Oats'],
    );
  }
}
