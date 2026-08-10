/// Grocery taxonomy used by the scan feature.
enum GroceryCategory {
  produce,
  meat,
  dairy,
  pantry;

  String get label => switch (this) {
        GroceryCategory.produce => 'Produce',
        GroceryCategory.meat => 'Meat',
        GroceryCategory.dairy => 'Dairy',
        GroceryCategory.pantry => 'Pantry',
      };
}

/// A grocery item as known by the embedded dictionary.
///
/// The same canonical item can have several display variants
/// (e.g. `Tomatoes` vs `Organic Tomatoes`) — see `grocery_dictionary.dart`.
class GroceryItem {
  const GroceryItem({
    required this.id,
    required this.name,
    required this.category,
    this.unit = 'lb',
    this.isOrganic = false,
  });

  final String id;
  final String name;
  final GroceryCategory category;

  /// Pricing unit, e.g. `lb` → "$5.99 / lb".
  final String unit;

  /// Whether this is an organic variant (drives badge UI in choosers).
  final bool isOrganic;

  GroceryItem copyWith({bool? isOrganic, String? name}) => GroceryItem(
        id: id,
        name: name ?? this.name,
        category: category,
        unit: unit,
        isOrganic: isOrganic ?? this.isOrganic,
      );

  @override
  String toString() => 'GroceryItem($name)';
}
