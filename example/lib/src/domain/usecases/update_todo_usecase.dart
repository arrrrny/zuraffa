import 'package:zuraffa/zuraffa.dart';

import '../entities/todo.dart';
import '../repositories/todo_repository.dart';

/// Applies a [TodoPatch] to an existing [Todo].
///
/// The patch is applied in the datasource so only the fields present
/// in the patch are modified. Uses zorphy's generated [TodoPatch] class
/// for type-safe partial updates.
///
/// Example — toggle completion:
/// ```dart
/// await updateTodo(UpdateParams(
///   id: todo.id,
///   data: TodoPatch().withIsCompleted(!todo.isCompleted)
///     .withCompletedAt(DateTime.now()),
/// ));
/// ```
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
