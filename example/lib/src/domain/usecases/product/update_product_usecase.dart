import 'package:zuraffa/zuraffa.dart';

import '../../entities/product/product.dart';
import '../../repositories/product_repository.dart';

class UpdateProductUseCase
    extends UseCase<Product, UpdateParams<String, ProductPatch>> {
  UpdateProductUseCase(this._repository);

  final ProductRepository _repository;

  @override
  Future<Product> execute(
    UpdateParams<String, ProductPatch> params,
    CancelToken? cancelToken,
  ) async {
    cancelToken?.throwIfCancelled();
    return _repository.update(params);
  }
}
