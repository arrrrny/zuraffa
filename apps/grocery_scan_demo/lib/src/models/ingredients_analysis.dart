/// Result of an ingredients photo check — the stethoscope mode.
///
/// Mirrors the ZikZakScore concept but health-oriented: the camera captures
/// the ingredient list, full text is extracted, and an AI model returns the
/// gluten verdict + a nutrition score with factor breakdown. Everything is
/// mocked here — the real wiring (same as ZikZakScore on the Listing Sheet)
/// just replaces [MockGroceryProvider.scanIngredients] with the AI call.
library;

/// Gluten verdict of the scanned product.
enum GlutenVerdict {
  /// Ingredient list contains explicit gluten sources (wheat, barley, rye…).
  contains,

  /// Listed as gluten-free / no gluten sources found.
  free,

  /// "May contain traces" or ambiguous wording.
  mayContain;

  String get label => switch (this) {
        GlutenVerdict.contains => 'Contains gluten',
        GlutenVerdict.free => 'Gluten-free',
        GlutenVerdict.mayContain => 'May contain gluten',
      };
}

/// One nutrition factor of the score breakdown (sugar, sodium, fiber…).
class NutritionFactor {
  const NutritionFactor({
    required this.label,
    required this.value,
    required this.score,
    required this.isBeneficial,
  });

  final String label;

  /// Human value, e.g. "9g", "420mg".
  final String value;

  /// 0..100 — how good this factor is.
  final int score;

  /// Positive factors (protein, fiber) score green; negative (sugar,
  /// saturated fat, sodium) score red when high.
  final bool isBeneficial;
}

/// Ingredients photo analysis (mocked).
class IngredientsAnalysis {
  const IngredientsAnalysis({
    required this.productName,
    required this.brand,
    required this.verdict,
    required this.nutritionScore,
    required this.factors,
    required this.ingredients,
    required this.glutenSources,
  });

  final String productName;
  final String brand;
  final GlutenVerdict verdict;

  /// 0..100 health score.
  final int nutritionScore;

  final List<NutritionFactor> factors;

  /// Full ingredient list as read from the package.
  final List<String> ingredients;

  /// Ingredients that are gluten sources — highlighted on the overlay.
  final List<String> glutenSources;

  bool get isGlutenFree => verdict == GlutenVerdict.free;
}
