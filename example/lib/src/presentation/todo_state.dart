import 'package:zuraffa/zuraffa.dart';

import '../domain/entities/enums/index.dart';
import '../domain/entities/todo/todo.dart';

/// Immutable UI state for the Todo feature.
///
/// This file is HAND-WRITTEN (spec 031 US4): the CLI does not generate
/// presentation code. Its shape is determined by UI needs, not domain
/// constraints — it composes only CLI-generated artifacts
/// ([Todo], [TodoPriority], [AppFailure]).
class TodoState {
  const TodoState({
    this.error,
    this.todoList = const [],
    this.activeFilter,
    this.isCreating = false,
    this.isDeleting = false,
    this.isLoading = false,
  });

  final AppFailure? error;
  final List<Todo> todoList;
  final TodoPriority? activeFilter;
  final bool isCreating;
  final bool isDeleting;
  final bool isLoading;

  bool get hasError => error != null;

  TodoState copyWith({
    AppFailure? error,
    List<Todo>? todoList,
    TodoPriority? activeFilter,
    bool? isCreating,
    bool? isDeleting,
    bool? isLoading,
  }) {
    return TodoState(
      error: error ?? this.error,
      todoList: todoList ?? this.todoList,
      activeFilter: activeFilter ?? this.activeFilter,
      isCreating: isCreating ?? this.isCreating,
      isDeleting: isDeleting ?? this.isDeleting,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// Clears the current error (used after the UI has shown it).
  TodoState clearError() => TodoState(
    todoList: todoList,
    activeFilter: activeFilter,
    isCreating: isCreating,
    isDeleting: isDeleting,
    isLoading: isLoading,
  );
}
