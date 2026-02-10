import 'package:zuraffa/zuraffa.dart';

import '../../entities/todo/todo.dart';
import '../../repositories/todo_repository.dart';

class WatchTodoUseCase extends StreamUseCase<Todo, QueryParams<Todo>> {
  WatchTodoUseCase(this._repository);

  final TodoRepository _repository;

  @override
  Stream<Todo> execute(QueryParams<Todo> params, CancelToken? cancelToken) {
    cancelToken?.throwIfCancelled();
    return _repository.watch(params);
  }
}
