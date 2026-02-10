import 'package:zuraffa/zuraffa.dart';

import '../../entities/product/product.dart';
import '../../repositories/product_repository.dart';

class CreateProductUseCase extends UseCase<Product, Product> {
  CreateProductUseCase(this._repository);

  final ProductRepository _repository;

  @override
  Future<Product> execute(Product params, CancelToken? cancelToken) async {
    cancelToken?.throwIfCancelled();
    return _repository.create(params);
  }
}
