/// UpdateProductUseCase (fixture for spec 043 slice tests).
library;

import '../../entities/product/product.dart';
import '../../repositories/product_repository.dart';

/// Persists product edits.
class UpdateProductUseCase {
  /// Creates the usecase.
  UpdateProductUseCase(this._repository);

  final ProductRepository _repository;

  /// Executes the update for [product].
  Future<void> execute(Product product) => _repository.updateProduct(product);
}
