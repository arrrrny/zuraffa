import 'package:zuraffa/zuraffa.dart';

import '../../entities/product/product.dart';
import '../../repositories/product_repository.dart';

class UpdateProductUseCase
    extends UseCase<Product, UpdateParams<String, Partial<Product>>> {
  UpdateProductUseCase(this._repository);

  final ProductRepository _repository;

  @override
  Future<Product> execute(
    UpdateParams<String, Partial<Product>> params,
    CancelToken? cancelToken,
  ) async {
    cancelToken?.throwIfCancelled();
    return _repository.update(params);
  }
}
