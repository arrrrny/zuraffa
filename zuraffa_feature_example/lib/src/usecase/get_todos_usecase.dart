import '../repository/todo_repository.dart';

/// Use case that retrieves all todo items.
class GetTodosUseCase {
  final TodoRepository _repository;

  GetTodosUseCase(this._repository);

  List<Map<String, dynamic>> call() {
    return _repository.getAll();
  }
}
