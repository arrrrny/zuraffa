import 'dart:async';

import 'package:example/src/data/data_sources/todo/todo_data_source.dart';
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/todo/todo.dart';

///
/// This is a simple implementation for demonstration purposes.
/// In a real app, you'd implement against an API or local database.
class InMemoryTodoDataSource
    with Loggable, FailureHandler
    implements TodoDataSource {
  final List<Todo> _todos = [];
  int _nextId = 1;

  final _controller = StreamController<List<Todo>>.broadcast();

  /// Create a repository with optional initial todos.
  InMemoryTodoDataSource({List<Todo>? initialTodos}) {
    if (initialTodos != null) {
      _todos.addAll(initialTodos);
      if (initialTodos.isNotEmpty) {
        _nextId =
            initialTodos.map((t) => t.id).reduce((a, b) => a > b ? a : b) + 1;
      }
    }
  }

  void _notifyListeners() {
    _controller.add(List.unmodifiable(_todos));
  }

  int _parseId(String id) {
    return int.tryParse(id) ?? -1;
  }

  @override
  Future<Todo> get(String id) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));
    final intId = _parseId(id);
    final todo = _todos.where((t) => t.id == intId).firstOrNull;
    if (todo == null) {
      throw Exception('Todo with id $id not found');
    }
    return todo;
  }

  @override
  Future<List<Todo>> getList(ListQueryParams<Todo> params) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    var result = List<Todo>.from(_todos);

    // Apply filtering if needed (e.g., search)
    if (params.search != null && params.search!.isNotEmpty) {
      final query = params.search!.toLowerCase();
      result =
          result.where((t) => t.title.toLowerCase().contains(query)).toList();
    }

    // Apply sorting
    if (params.sort != null) {
      // Simple sorting logic for demonstration
      result.sort((a, b) {
        // Implementation depends on fields available
        return params.sort!.descending
            ? b.id.compareTo(a.id)
            : a.id.compareTo(b.id);
      });
    }

    return result;
  }

  @override
  Stream<Todo> watch(String id) {
    final intId = _parseId(id);
    return _controller.stream.map((todos) {
      final todo = todos.where((t) => t.id == intId).firstOrNull;
      if (todo == null) {
        throw Exception('Todo with id $id not found');
      }
      return todo;
    }).distinct();
  }

  @override
  Stream<List<Todo>> watchList(ListQueryParams params) {
    // Emit current state immediately then updates
    return _controller.stream.startWith(List.unmodifiable(_todos)).map((todos) {
      var result = List<Todo>.from(todos);

      if (params.search != null && params.search!.isNotEmpty) {
        final query = params.search!.toLowerCase();
        result =
            result.where((t) => t.title.toLowerCase().contains(query)).toList();
      }

      return result;
    });
  }

  @override
  Future<Todo> create(Todo todo) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 200));

    final newTodo = todo.copyWith(id: _nextId++);
    _todos.add(newTodo);
    _notifyListeners();

    return newTodo;
  }

  @override
  Future<Todo> update(UpdateParams<Partial<Todo>> params) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 200));

    final intId = _parseId(params.id.toString());
    final index = _todos.indexWhere((t) => t.id == intId);

    if (index == -1) {
      throw Exception('Todo with id ${params.id} not found');
    }

    final currentTodo = _todos[index];

    // Apply partial updates
    final newTodo = currentTodo.copyWith(
      title: params.data['title'] as String?,
      isCompleted: params.data['isCompleted'] as bool?,
    );

    _todos[index] = newTodo;
    _notifyListeners();

    return newTodo;
  }

  @override
  Future<void> delete(DeleteParams<Todo> params) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 200));

    final intId = _parseId(params.id.toString());
    final index = _todos.indexWhere((t) => t.id == intId);

    if (index == -1) {
      throw Exception('Todo with id ${params.id} not found');
    }

    _todos.removeAt(index);
    _notifyListeners();
  }

  /// Dispose of resources.
  void dispose() {
    _controller.close();
  }
}

// Extension for startWith since standard stream doesn't have it easily available without rxdart
extension StreamStartWith<T> on Stream<T> {
  Stream<T> startWith(T initial) async* {
    yield initial;
    yield* this;
  }
}
