import 'package:zuraffa/zuraffa.dart';

import '../entities/todo.dart';
import '../repositories/todo_repository.dart';

/// Reactively watches a list of [Todo] entities.
///
/// Emits new lists whenever the underlying data changes, enabling
/// the UI to stay in sync without manual refresh calls.
///
/// Combine with zorphy [TodoFields] filters for live-filtered lists:
/// ```dart
/// watchTodoList(ListQueryParams<Todo>(
///   filter: TodoFields.isCompleted.eq(false),
/// ));
/// ```
class WatchTodoListUseCase
    extends StreamUseCase<List<Todo>, ListQueryParams<Todo>> {
  WatchTodoListUseCase(this._repository);

  final TodoRepository _repository;

  @override
  Stream<List<Todo>> execute(
    ListQueryParams<Todo> params,
    CancelToken? cancelToken,
  ) {
    cancelToken?.throwIfCancelled();
    return _repository.watchList(params);
  }
}
