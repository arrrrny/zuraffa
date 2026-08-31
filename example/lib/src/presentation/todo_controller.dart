import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:zuraffa/zuraffa.dart';

import '../domain/entities/enums/index.dart';
import '../domain/entities/todo/todo.dart';
import 'todo_presenter.dart';
import 'todo_state.dart';

/// Controller for the Todo feature.
///
/// HAND-WRITTEN (spec 031 US4): owns the [TodoState] and exposes methods
/// the view calls to trigger CRUD operations. Every method updates the
/// state and delegates to [TodoPresenter]. Notifies listeners via
/// [ChangeNotifier]; the page rebuilds on every state change.
class TodoController extends ChangeNotifier {
  TodoController(this._presenter);

  final TodoPresenter _presenter;

  TodoState _state = const TodoState();
  TodoState get state => _state;

  /// The subscription to the reactive todo list.
  StreamSubscription<Result<List<Todo>, AppFailure>>? _subscription;

  /// Starts watching the todo list reactively.
  ///
  /// Accepts an optional [filter] to narrow results using the
  /// zorphy-generated [TodoFields] descriptors.
  void watchTodoList([TodoPriority? filter]) {
    _state = _state.copyWith(isLoading: true, activeFilter: filter);
    notifyListeners();

    final params = filter != null
        ? ListQueryParams<Todo>(filter: Eq(TodoFields.priority, filter))
        : const ListQueryParams<Todo>();

    _subscription?.cancel();
    _subscription = _presenter.watchTodoList(params).listen((result) {
      result.fold(
        (list) => _apply(
          _state.copyWith(isLoading: false, todoList: list, error: null),
        ),
        (failure) => _apply(_state.copyWith(isLoading: false, error: failure)),
      );
    });
  }

  Future<void> createTodo(String title) async {
    if (title.trim().isEmpty) return;
    _state = _state.copyWith(isCreating: true);
    notifyListeners();

    final todo = Todo(
      id: DateTime.now().millisecondsSinceEpoch,
      title: title.trim(),
      description: '',
      isCompleted: false,
      priority: TodoPriority.medium,
      tags: const [],
      createdAt: DateTime.now(),
      completedAt: DateTime.now(),
    );

    final result = await _presenter.createTodo(todo);
    result.fold(
      (_) {
        _state = _state.copyWith(isCreating: false, error: null);
        notifyListeners();
      },
      (failure) {
        _state = _state.copyWith(isCreating: false, error: failure);
        notifyListeners();
      },
    );
  }

  Future<void> toggleTodo(Todo todo) async {
    final result = await _presenter.updateTodo(todo);
    result.fold(
      (_) => _state = _state.clearError(),
      (failure) => _state = _state.copyWith(error: failure),
    );
    notifyListeners();
  }

  Future<void> deleteTodo(Todo todo) async {
    _state = _state.copyWith(isDeleting: true);
    notifyListeners();

    final result = await _presenter.deleteTodo(todo.id);
    result.fold(
      (_) => _state = _state.copyWith(isDeleting: false, error: null),
      (failure) => _state = _state.copyWith(isDeleting: false, error: failure),
    );
    notifyListeners();
  }

  void dismissError() {
    _state = _state.clearError();
    notifyListeners();
  }

  void _apply(TodoState next) {
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
