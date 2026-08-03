import 'package:zuraffa/zuraffa.dart';

import '../entities/todo.dart';
import '../repositories/todo_repository.dart';

/// Reactively watches a single [Todo] entity.
///
/// Emits updated values whenever the entity changes, useful for detail
/// views that need to stay in sync with background updates.
class WatchTodoUseCase extends StreamUseCase<Todo, QueryParams<Todo>> {
  WatchTodoUseCase(this._repository);

  final TodoRepository _repository;

  @override
  Stream<Todo> execute(
    QueryParams<Todo> params,
    CancelToken? cancelToken,
  ) {
    cancelToken?.throwIfCancelled();
    return _repository.watch(params);
  }
}
