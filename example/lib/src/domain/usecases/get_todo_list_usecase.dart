import 'package:zuraffa/zuraffa.dart';

import '../entities/todo.dart';
import '../repositories/todo_repository.dart';

/// Retrieves a list of [Todo] entities matching query parameters.
///
/// Supports filtering with zorphy-generated [TodoFields] descriptors,
/// sorting, and pagination via [ListQueryParams].
///
/// Example — filter by priority:
/// ```dart
/// final result = await getTodoList(
///   ListQueryParams<Todo>(
///     filter: TodoFields.priority.eq(TodoPriority.high),
///   ),
/// );
/// ```
class GetTodoListUseCase extends UseCase<List<Todo>, ListQueryParams<Todo>> {
  GetTodoListUseCase(this._repository);

  final TodoRepository _repository;

  @override
  Future<List<Todo>> execute(
    ListQueryParams<Todo> params,
    CancelToken? cancelToken,
  ) async {
    cancelToken?.throwIfCancelled();
    return _repository.getList(params);
  }
}
