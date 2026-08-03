import 'package:zuraffa/zuraffa.dart';

import '../domain/domain.dart';
import 'todo_presenter.dart';
import 'todo_state.dart';

/// Controller for the Todo feature.
///
/// Owns the [TodoState] and exposes methods the view calls to
/// trigger CRUD operations. Every method updates the state and
/// delegates to [TodoPresenter].
///
/// The [Controller] base class provides lifecycle management,
/// automatic cancellation of pending operations on dispose, and
/// [ChangeNotifier] integration for [ControlledWidgetBuilder].
class TodoController extends Controller with StatefulController<TodoState> {
  TodoController(this._presenter) : super();

  final TodoPresenter _presenter;

  @override
  TodoState createInitialState() => const TodoState();

  // ── List operations ─────────────────────────────────────────

  /// Starts watching the todo list reactively.
  ///
  /// Accepts an optional [filter] to narrow results using
  /// zorphy-generated [TodoFields] descriptors.
  void watchTodoList([TodoPriority? filter]) {
    updateState(viewState.copyWith(
      isLoading: true,
      activeFilter: filter,
    ));

    ListQueryParams<Todo> params;
    if (filter != null) {
      params = ListQueryParams<Todo>(
        filter: TodoFields.priority.eq(filter),
      );
    } else {
      params = const ListQueryParams();
    }

    _presenter.watchTodoList(params).listen((result) {
      result.fold(
        (list) => updateState(viewState.copyWith(isLoading: false, todoList: list)),
        (failure) => updateState(viewState.copyWith(isLoading: false, error: failure)),
      );
    });
  }

  // ── Write operations ─────────────────────────────────────────

  Future<void> createTodo(Todo todo) async {
    updateState(viewState.copyWith(isCreating: true));
    final result = await _presenter.createTodo(todo);
    result.fold(
      (_) => updateState(viewState.copyWith(isCreating: false)),
      (failure) => updateState(viewState.copyWith(isCreating: false, error: failure)),
    );
  }

  /// Toggles the [isCompleted] flag using zorphy's [TodoPatch].
  ///
  /// The patch only touches `isCompleted` and `completedAt` — all
  /// other fields remain unchanged. This is the recommended way to
  /// do partial updates with zorphy entities.
  Future<void> toggleTodo(int id) async {
    final todo = viewState.todoList.where((t) => t.id == id).firstOrNull;
    if (todo == null) return;

    final completedAt = !todo.isCompleted ? DateTime.now() : todo.createdAt;

    final result = await _presenter.updateTodo(
      id,
      TodoPatch()
          .withIsCompleted(!todo.isCompleted)
          .withCompletedAt(completedAt),
    );

    result.fold(
      (_) {}, // State updates reactively via the watch stream.
      (failure) => updateState(viewState.copyWith(error: failure)),
    );
  }

  /// Optimistically removes a todo from the list, then deletes it.
  ///
  /// The optimistic removal lets the [Dismissible] animation
  /// complete without errors. If deletion fails, the watch stream
  /// will re-add the item.
  Future<void> deleteTodo(int id) async {
    updateState(viewState.copyWith(
      isDeleting: true,
      todoList: viewState.todoList.where((e) => e.id != id).toList(),
    ));

    final result = await _presenter.deleteTodo(id);
    result.fold(
      (_) => updateState(viewState.copyWith(isDeleting: false)),
      (failure) => updateState(viewState.copyWith(isDeleting: false, error: failure)),
    );
  }

  /// Clears the current error.
  void clearError() {
    updateState(viewState.copyWith(clearError: true));
  }

  /// Clears the active priority filter.
  void clearFilter() {
    watchTodoList();
  }

  @override
  void onDisposed() {
    _presenter.dispose();
    super.onDisposed();
  }
}
