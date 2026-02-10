import 'package:zuraffa/zuraffa.dart';

import '../../entities/product/product.dart';
import '../../repositories/product_repository.dart';

class WatchProductUseCase extends StreamUseCase<Product, QueryParams<Product>> {
  WatchProductUseCase(this._repository);

  final ProductRepository _repository;

  @override
  Stream<Product> execute(
    QueryParams<Product> params,
    CancelToken? cancelToken,
  ) {
    cancelToken?.throwIfCancelled();
    return _repository.watch(params);
  }
}
