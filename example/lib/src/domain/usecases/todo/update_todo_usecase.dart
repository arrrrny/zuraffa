import 'package:zuraffa/zuraffa.dart';

import '../../entities/todo/todo.dart';
import '../../repositories/todo_repository.dart';

class UpdateTodoUseCase extends UseCase<Todo, UpdateParams<int, TodoPatch>> {
  UpdateTodoUseCase(this._repository);

  final TodoRepository _repository;

  @override
  Future<Todo> execute(
    UpdateParams<int, TodoPatch> params,
    CancelToken? cancelToken,
  ) async {
    cancelToken?.throwIfCancelled();
    return _repository.update(params);
  }
}
