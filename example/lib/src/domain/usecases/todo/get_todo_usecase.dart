import 'package:zuraffa/zuraffa.dart';

import '../../entities/todo/todo.dart';
import '../../repositories/todo_repository.dart';

class GetTodoUseCase extends UseCase<Todo, QueryParams<Todo>> {
  GetTodoUseCase(this._repository);

  final TodoRepository _repository;

  @override
  Future<Todo> execute(
    QueryParams<Todo> params,
    CancelToken? cancelToken,
  ) async {
    cancelToken?.throwIfCancelled();
    return _repository.get(params);
  }
}
