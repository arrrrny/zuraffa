/// Product entity (fixture for spec 043).
///
/// Carries a json_serializable-style generated companion (`product.g.dart`)
/// so the slice engine's companion detection has a real case (FR-006, U17).
library;

part 'product.g.dart';

/// A catalog product.
class Product {
  /// Creates a product.
  const Product({required this.id, required this.name, required this.price});

  /// Unique identifier.
  final String id;

  /// Display name.
  final String name;

  /// Price in minor units.
  final int price;

  /// Serializes the product to JSON.
  Map<String, dynamic> toJson() => _$ProductToJson(this);
}
