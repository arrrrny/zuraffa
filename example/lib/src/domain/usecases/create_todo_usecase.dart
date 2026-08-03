import 'package:zuraffa/zuraffa.dart';

import '../entities/todo.dart';
import '../repositories/todo_repository.dart';

/// Creates a new [Todo] and persists it.
///
/// Returns the persisted entity (which may have server-assigned fields
/// in a real app with a remote backend).
class CreateTodoUseCase extends UseCase<Todo, Todo> {
  CreateTodoUseCase(this._repository);

  final TodoRepository _repository;

  @override
  Future<Todo> execute(Todo params, CancelToken? cancelToken) async {
    cancelToken?.throwIfCancelled();
    return _repository.create(params);
  }
}
