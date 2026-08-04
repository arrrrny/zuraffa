/// Immutable state for the todo feature.
class TodoState {
  /// Whether the feature is loading.
  final bool isLoading;

  /// The list of todo items (immutable snapshot).
  final List<Map<String, dynamic>> todos;

  const TodoState({this.isLoading = false, this.todos = const []});

  TodoState copyWith({bool? isLoading, List<Map<String, dynamic>>? todos}) {
    return TodoState(
      isLoading: isLoading ?? this.isLoading,
      todos: todos != null
          ? List.unmodifiable(
              todos.map((todo) => Map<String, dynamic>.unmodifiable(todo)),
            )
          : this.todos,
    );
  }
}
