import 'package:flutter/foundation.dart';

import '../repository/todo_repository.dart';
import '../usecase/get_todos_usecase.dart';
import '../state/todo_state.dart';

/// Controller managing the todo feature state.
class TodoController extends ChangeNotifier {
  TodoState _state = const TodoState();
  TodoState get state => _state;

  final GetTodosUseCase _getTodos;
  final TodoRepository _repository;

  TodoController(this._repository)
      : _getTodos = GetTodosUseCase(_repository);

  void loadTodos() {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();
    final todos = _getTodos.call();
    _state = _state.copyWith(isLoading: false, todos: todos);
    notifyListeners();
  }

  void addTodo(String title) {
    _repository.add(title);
    loadTodos();
  }

  void removeTodo(int index) {
    _repository.removeAt(index);
    loadTodos();
  }

  void toggleTodo(int index) {
    _repository.toggleCompleted(index);
    loadTodos();
  }
}
