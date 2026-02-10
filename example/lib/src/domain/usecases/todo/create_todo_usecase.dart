import 'package:zuraffa/zuraffa.dart';

import '../../entities/todo/todo.dart';
import '../../repositories/todo_repository.dart';

class CreateTodoUseCase extends UseCase<Todo, Todo> {
  CreateTodoUseCase(this._repository);

  final TodoRepository _repository;

  @override
  Future<Todo> execute(Todo params, CancelToken? cancelToken) async {
    cancelToken?.throwIfCancelled();
    return _repository.create(params);
  }
}
