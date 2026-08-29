/// Remote product datasource (fixture for spec 043 slice tests).
library;

import '../../domain/entities/product/product.dart';

/// Talks to the product backend.
class ProductRemoteDataSource {
  /// Fetches raw product JSON for [id].
  Future<Map<String, dynamic>> fetchProduct(String id) async =>
      {'id': id, 'name': 'Remote product', 'price': 100};
}

/// Standalone constant so the datasource file declares two symbols.
const int kProductRemoteTimeoutMs = 5000;
