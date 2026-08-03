import 'package:zuraffa/zuraffa.dart';

import '../entities/todo.dart';
import '../repositories/todo_repository.dart';

/// Retrieves a single [Todo] by query parameters.
///
/// Typical usage:
/// ```dart
/// final result = await getTodo(
///   QueryParams<Todo>(filter: Eq(TodoFields.id, 42)),
/// );
/// ```
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
