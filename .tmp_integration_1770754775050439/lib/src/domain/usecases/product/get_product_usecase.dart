import 'package:zuraffa/zuraffa.dart';

import '../../entities/product/product.dart';
import '../../repositories/product_repository.dart';

class GetProductUseCase extends UseCase<Product, QueryParams<Product>> {
  GetProductUseCase(this._repository);

  final ProductRepository _repository;

  @override
  Future<Product> execute(
    QueryParams<Product> params,
    CancelToken? cancelToken,
  ) async {
    cancelToken?.throwIfCancelled();
    return _repository.get(params);
  }
}
