/// GetProductUseCase (fixture for spec 043 slice tests).
library;

import '../../entities/product/product.dart';
import '../../repositories/product_repository.dart';

/// Loads a single product.
class GetProductUseCase {
  /// Creates the usecase.
  GetProductUseCase(this._repository);

  final ProductRepository _repository;

  /// Executes the load for [id].
  Future<Product> execute(String id) => _repository.getProduct(id);
}
