import 'package:zuraffa/zuraffa.dart';

import '../../repositories/product_repository.dart';

class DeleteProductUseCase extends CompletableUseCase<DeleteParams<String>> {
  DeleteProductUseCase(this._repository);

  final ProductRepository _repository;

  @override
  Future<void> execute(
    DeleteParams<String> params,
    CancelToken? cancelToken,
  ) async {
    cancelToken?.throwIfCancelled();
    return _repository.delete(params);
  }
}
