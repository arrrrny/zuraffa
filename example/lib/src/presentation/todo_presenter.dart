import 'package:zuraffa/zuraffa.dart';

import '../domain/entities/todo/todo.dart';
import '../domain/usecases/todo/create_todo_usecase.dart';
import '../domain/usecases/todo/delete_todo_usecase.dart';
import '../domain/usecases/todo/get_todo_list_usecase.dart';
import '../domain/usecases/todo/get_todo_usecase.dart';
import '../domain/usecases/todo/update_todo_usecase.dart';
import '../domain/usecases/todo/watch_todo_list_usecase.dart';
import '../domain/usecases/todo/watch_todo_usecase.dart';

/// Presenter for the Todo feature.
///
/// HAND-WRITTEN (spec 031 US4): mediates between the controller (UI
/// logic) and the CLI-generated use cases. Each public method wraps a
/// single use case call and returns a [Result] (or a [Stream] of
/// results for the watch use cases) so the controller can handle
/// success/failure uniformly.
///
/// All seven use cases are resolved from get_it — they were registered
/// by the generated DI layer (`lib/src/di/`, emitted by
/// `zfa make --preset=crud`).
class TodoPresenter {
  final GetTodoUseCase _getTodo;
  final GetTodoListUseCase _getTodoList;
  final WatchTodoUseCase _watchTodo;
  final WatchTodoListUseCase _watchTodoList;
  final CreateTodoUseCase _createTodo;
  final UpdateTodoUseCase _updateTodo;
  final DeleteTodoUseCase _deleteTodo;

  TodoPresenter({required GetIt getIt})
    : _getTodo = getIt<GetTodoUseCase>(),
      _getTodoList = getIt<GetTodoListUseCase>(),
      _watchTodo = getIt<WatchTodoUseCase>(),
      _watchTodoList = getIt<WatchTodoListUseCase>(),
      _createTodo = getIt<CreateTodoUseCase>(),
      _updateTodo = getIt<UpdateTodoUseCase>(),
      _deleteTodo = getIt<DeleteTodoUseCase>();

  Future<Result<Todo, AppFailure>> getTodo(int id) {
    return _getTodo(QueryParams<Todo>(filter: Eq(TodoFields.id, id)));
  }

  Future<Result<List<Todo>, AppFailure>> getTodoList([
    ListQueryParams<Todo> params = const ListQueryParams(),
  ]) {
    return _getTodoList(params);
  }

  Stream<Result<Todo, AppFailure>> watchTodo([
    QueryParams<Todo> params = const QueryParams<Todo>(),
  ]) {
    return _watchTodo(params);
  }

  Stream<Result<List<Todo>, AppFailure>> watchTodoList([
    ListQueryParams<Todo> params = const ListQueryParams(),
  ]) {
    return _watchTodoList(params);
  }

  Future<Result<Todo, AppFailure>> createTodo(Todo todo) {
    return _createTodo(todo);
  }

  Future<Result<Todo, AppFailure>> updateTodo(Todo todo) {
    return _updateTodo(
      UpdateParams<int, TodoPatch>(
        id: todo.id,
        data: TodoPatch().withIsCompleted(!todo.isCompleted),
      ),
    );
  }

  Future<Result<void, AppFailure>> deleteTodo(int id) {
    return _deleteTodo(DeleteParams<int>(id: id));
  }
}
