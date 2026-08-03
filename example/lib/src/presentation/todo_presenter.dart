import 'package:zuraffa/zuraffa.dart';

import '../domain/domain.dart';

/// Presenter for the Todo feature.
///
/// Mediates between the controller (UI logic) and the domain layer
/// (use cases + repository). Each public method wraps a use case call
/// and returns a [Result] so the controller can handle success/failure
/// uniformly.
///
/// Use cases are registered via [Presenter.registerUseCase] so they
/// are automatically tracked for disposal when the presenter is
/// disposed.
class TodoPresenter extends Presenter {
  final TodoRepository _repository;

  late final GetTodoUseCase _getTodo;
  late final GetTodoListUseCase _getTodoList;
  late final WatchTodoUseCase _watchTodo;
  late final WatchTodoListUseCase _watchTodoList;
  late final CreateTodoUseCase _createTodo;
  late final UpdateTodoUseCase _updateTodo;
  late final DeleteTodoUseCase _deleteTodo;

  TodoPresenter({required TodoRepository repository})
      : _repository = repository {
    _getTodo = registerUseCase(GetTodoUseCase(_repository));
    _getTodoList = registerUseCase(GetTodoListUseCase(_repository));
    _watchTodo = registerUseCase(WatchTodoUseCase(_repository));
    _watchTodoList = registerUseCase(WatchTodoListUseCase(_repository));
    _createTodo = registerUseCase(CreateTodoUseCase(_repository));
    _updateTodo = registerUseCase(UpdateTodoUseCase(_repository));
    _deleteTodo = registerUseCase(DeleteTodoUseCase(_repository));
  }

  Future<Result<Todo, AppFailure>> getTodo(int id) {
    return _getTodo(
      QueryParams<Todo>(filter: Eq(TodoFields.id, id)),
    );
  }

  Future<Result<List<Todo>, AppFailure>> getTodoList([
    ListQueryParams<Todo> params = const ListQueryParams(),
  ]) {
    return _getTodoList(params);
  }

  Stream<Result<Todo, AppFailure>> watchTodo(int id) {
    return _watchTodo(
      QueryParams<Todo>(filter: Eq(TodoFields.id, id)),
    );
  }

  Stream<Result<List<Todo>, AppFailure>> watchTodoList([
    ListQueryParams<Todo> params = const ListQueryParams(),
  ]) {
    return _watchTodoList(params);
  }

  Future<Result<Todo, AppFailure>> createTodo(Todo todo) {
    return _createTodo(todo);
  }

  Future<Result<Todo, AppFailure>> updateTodo(int id, TodoPatch data) {
    return _updateTodo(UpdateParams(id: id, data: data));
  }

  Future<Result<void, AppFailure>> deleteTodo(int id) {
    return _deleteTodo(DeleteParams(id: id));
  }
}
