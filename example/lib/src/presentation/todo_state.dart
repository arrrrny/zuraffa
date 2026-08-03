import 'package:zuraffa/zuraffa.dart';

import '../domain/entities/todo.dart';

/// Immutable UI state for the Todo feature.
///
/// Tracks loading flags per operation, the entity list, active
/// filter, and any failure that needs to be surfaced to the UI.
///
/// This is hand-written (not zorphy-generated) because it lives in
/// the presentation layer and its shape is determined by UI needs,
/// not domain constraints.
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

  TodoState copyWith({
    AppFailure? error,
    bool clearError = false,
    List<Todo>? todoList,
    TodoPriority? activeFilter,
    bool clearFilter = false,
    bool? isCreating,
    bool? isDeleting,
    bool? isLoading,
  }) {
    return TodoState(
      error: clearError ? null : (error ?? this.error),
      todoList: todoList ?? this.todoList,
      activeFilter: clearFilter ? null : (activeFilter ?? this.activeFilter),
      isCreating: isCreating ?? this.isCreating,
      isDeleting: isDeleting ?? this.isDeleting,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoState &&
          runtimeType == other.runtimeType &&
          todoList == other.todoList &&
          error == other.error &&
          activeFilter == other.activeFilter &&
          isCreating == other.isCreating &&
          isDeleting == other.isDeleting &&
          isLoading == other.isLoading);

  @override
  int get hashCode =>
      todoList.hashCode ^
      error.hashCode ^
      activeFilter.hashCode ^
      isCreating.hashCode ^
      isDeleting.hashCode ^
      isLoading.hashCode;

  @override
  String toString() =>
      'TodoState(todos: ${todoList.length}, filter: $activeFilter, '
      'creating: $isCreating, loading: $isLoading, error: $error)';
}
