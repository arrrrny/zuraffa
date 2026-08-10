import '../models/grocery_item.dart';

/// Embedded, localized grocery dictionary.
///
/// Mirrors how category configs are embedded per country: each supported
/// locale maps a detected product key to its human display variants. This is
/// what powers the "approve the exact item" edge case of object detection:
///
/// - `cantaloupe` has exactly ONE variant → no prompt, straight to pricing.
/// - `tomato` has several variants (conventional / organic / heirloom) →
///   the customer confirms which one before prices are compared.
///
/// Embedded in the app on purpose — no network round-trip, works offline
/// in-store, just like the category configs.
abstract final class GroceryDictionary {
  GroceryDictionary._();

  static const String defaultLocale = 'en-US';

  /// Locales shipped inside the app binary.
  static const List<String> supportedLocales = ['en-US', 'tr-TR'];

  /// productKey → display variants, per locale.
  ///
  /// The first variant is the "conventional" baseline; later entries are
  /// alternatives (organic, heirloom, brand…).
  static const Map<String, Map<String, List<String>>> _entries = {
    'en-US': {
      // Produce
      'tomato': ['Tomatoes', 'Organic Tomatoes', 'Heirloom Tomatoes'],
      'cantaloupe': ['Cantaloupe'],
      'avocado': ['Avocados', 'Organic Avocados', 'Hass Avocados'],
      'apple': ['Gala Apples', 'Honeycrisp Apples', 'Organic Gala Apples'],
      'banana': ['Bananas'],
      'lettuce': ['Romaine Lettuce', 'Organic Romaine Lettuce'],
      // Meat
      'steak': ['Ribeye Steak', 'Sirloin Steak', 'Organic Ribeye Steak'],
      'chicken': ['Chicken Breast', 'Organic Chicken Breast'],
      'ground-beef': ['Ground Beef 80/20', 'Ground Beef 93/7'],
      // Dairy & pantry
      'milk': ['Whole Milk', 'Organic Whole Milk', 'Lactose-Free Milk'],
      'eggs': ['Large Eggs', 'Organic Large Eggs', 'Free-Range Eggs'],
      'bread': ['Sourdough Bread', 'Whole Wheat Bread'],
    },
    'tr-TR': {
      'tomato': ['Domates', 'Organik Domates', 'Yerli Domates'],
      'cantaloupe': ['Kavun'],
      'avocado': ['Avokado', 'Organik Avokado'],
      'apple': ['Golden Elma', 'Granny Smith Elma', 'Organik Elma'],
      'steak': ['Bonfile', 'Antrikot', 'Organik Bonfile'],
      'chicken': ['Tavuk Göğsü', 'Organik Tavuk Göğsü'],
      'milk': ['Tam Yağlı Süt', 'Organik Süt'],
      'eggs': ['Köy Yumurtası', 'Organik Yumurta'],
    },
  };

  static const Map<String, GroceryCategory> _categoryByKey = {
    'tomato': GroceryCategory.produce,
    'cantaloupe': GroceryCategory.produce,
    'avocado': GroceryCategory.produce,
    'apple': GroceryCategory.produce,
    'banana': GroceryCategory.produce,
    'lettuce': GroceryCategory.produce,
    'steak': GroceryCategory.meat,
    'chicken': GroceryCategory.meat,
    'ground-beef': GroceryCategory.meat,
    'milk': GroceryCategory.dairy,
    'eggs': GroceryCategory.dairy,
    'bread': GroceryCategory.pantry,
  };

  /// True when the locale ships in the binary.
  static bool supportsLocale(String locale) => _entries.containsKey(locale);

  /// All known product keys for a locale.
  static List<String> keysFor(String locale) =>
      _entries[locale]?.keys.toList() ?? const [];

  /// Display variants for a detected product key.
  static List<GroceryItem> variantsFor(String locale, String productKey) {
    final variants = _entries[locale]?[productKey];
    if (variants == null) return const [];
    final category = _categoryByKey[productKey] ?? GroceryCategory.produce;
    return [
      for (final (i, name) in variants.indexed)
        GroceryItem(
          id: '$productKey::$i',
          name: name,
          category: category,
          isOrganic: name.toLowerCase().contains('organic') ||
              (locale == 'tr-TR' && name.toLowerCase().contains('organik')),
        ),
    ];
  }

  /// Matches a detected text / object label to a product key.
  ///
  /// Normalizes case and punctuation, then tries an exact match on the
  /// canonical key or any of its display variants. Falls back to [defaultKey]
  /// when nothing matches (mock scanner guarantees a match in this demo).
  static String? resolveKey(
    String locale,
    String detected, {
    String? defaultKey,
  }) {
    final normalized = _normalize(detected);
    if (normalized.isEmpty) return defaultKey;

    final entries = _entries[locale] ?? const {};
    for (final entry in entries.entries) {
      if (_normalize(entry.key) == normalized) return entry.key;
      for (final variant in entry.value) {
        if (_normalize(variant) == normalized) return entry.key;
      }
    }
    return defaultKey;
  }

  static String _normalize(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9üöşçği]'), '');
}
