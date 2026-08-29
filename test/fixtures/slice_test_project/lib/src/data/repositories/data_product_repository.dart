/// Data-layer ProductRepository implementation (fixture for spec 043).
library;

import '../domain/entities/product/product.dart';
import '../domain/repositories/product_repository.dart';
import 'datasources/product_remote_datasource.dart';

/// Implements [ProductRepository] against the remote datasource.
class DataProductRepository implements ProductRepository {
  /// Creates the repository.
  DataProductRepository(this._dataSource);

  final ProductRemoteDataSource _dataSource;

  @override
  Future<Product> getProduct(String id) async {
    final raw = await _dataSource.fetchProduct(id);
    return Product(
      id: raw['id'] as String,
      name: raw['name'] as String,
      price: raw['price'] as int,
    );
  }

  @override
  Future<void> updateProduct(Product product) async {
    // Would PATCH to the backend.
  }

  @override
  Stream<int> watchProductPrice(String id) async* {
    yield 100;
  }
}
