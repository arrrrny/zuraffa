import 'package:zuraffa/zuraffa.dart';

import '../../repositories/todo_repository.dart';

class DeleteTodoUseCase extends CompletableUseCase<DeleteParams<int>> {
  DeleteTodoUseCase(this._repository);

  final TodoRepository _repository;

  @override
  Future<void> execute(
    DeleteParams<int> params,
    CancelToken? cancelToken,
  ) async {
    cancelToken?.throwIfCancelled();
    return _repository.delete(params);
  }
}
