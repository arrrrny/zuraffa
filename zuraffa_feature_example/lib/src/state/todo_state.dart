/// Immutable state for the todo feature.
class TodoState {
  /// Whether the feature is loading.
  final bool isLoading;

  /// The list of todo items.
  final List<Map<String, dynamic>> todos;

  const TodoState({this.isLoading = false, this.todos = const []});

  TodoState copyWith({bool? isLoading, List<Map<String, dynamic>>? todos}) {
    return TodoState(
      isLoading: isLoading ?? this.isLoading,
      todos: todos ?? this.todos,
    );
  }
}
