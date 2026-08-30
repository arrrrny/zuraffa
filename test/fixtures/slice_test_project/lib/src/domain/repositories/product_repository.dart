/// Product repository contract (fixture for spec 043 slice tests).
library;

import '../entities/product/product.dart';

/// Boundary interface for product persistence.
abstract class ProductRepository {
  /// Fetches a product by [id].
  Future<Product> getProduct(String id);

  /// Persists [product].
  Future<void> updateProduct(Product product);

  /// Streams price changes for [id].
  Stream<int> watchProductPrice(String id);
}
