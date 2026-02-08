import 'dart:async';

import 'package:example/src/data/data_sources/todo/todo_data_source.dart';
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/todo/todo.dart';

class TodoRemoteDataSource
    with Loggable, FailureHandler
    implements TodoDataSource {
  final List<Todo> _todos = [];
  int _nextId = 1;

  final _controller = StreamController<List<Todo>>.broadcast();

  TodoRemoteDataSource({List<Todo>? initialTodos}) {
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

  @override
  Future<Todo> get(QueryParams<Todo> params) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final intId =
        params.filter != null ? (params.filter!.toJson()['id'] as int?) : null;
    if (intId == null) {
      throw Exception('Query requires filter with id');
    }
    final todo = _todos.where((t) => t.id == intId).firstOrNull;
    if (todo == null) {
      throw Exception('Todo with id $intId not found');
    }
    return todo;
  }

  @override
  Future<List<Todo>> getList(ListQueryParams<Todo> params) async {
    await Future.delayed(const Duration(milliseconds: 500));
    var result = List<Todo>.from(_todos);

    if (params.search != null && params.search!.isNotEmpty) {
      final query = params.search!.toLowerCase();
      result =
          result.where((t) => t.title.toLowerCase().contains(query)).toList();
    }

    return result;
  }

  @override
  Stream<Todo> watch(QueryParams<Todo> params) {
    final intId =
        params.filter != null ? (params.filter!.toJson()['id'] as int?) : null;
    return _controller.stream.map((todos) {
      final todo = todos.where((t) => t.id == intId).firstOrNull;
      if (todo == null) {
        throw Exception('Todo with id $intId not found');
      }
      return todo;
    }).distinct();
  }

  @override
  Stream<List<Todo>> watchList(ListQueryParams<Todo> params) {
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
    await Future.delayed(const Duration(milliseconds: 200));

    final newTodo = todo.copyWith(id: _nextId++);
    _todos.add(newTodo);
    _notifyListeners();

    return newTodo;
  }

  @override
  Future<Todo> update(UpdateParams<int, TodoPatch> params) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final index = _todos.indexWhere((t) => t.id == params.id);

    if (index == -1) {
      throw Exception('Todo with id ${params.id} not found');
    }

    final currentTodo = _todos[index];
    final newTodo = params.data.applyTo(currentTodo);

    _todos[index] = newTodo;
    _notifyListeners();

    return newTodo;
  }

  @override
  Future<void> delete(DeleteParams<int> params) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final index = _todos.indexWhere((t) => t.id == params.id);

    if (index == -1) {
      throw Exception('Todo with id ${params.id} not found');
    }

    _todos.removeAt(index);
    _notifyListeners();
  }

  void dispose() {
    _controller.close();
  }
}

extension StreamStartWith<T> on Stream<T> {
  Stream<T> startWith(T initial) async* {
    yield initial;
    yield* this;
  }
}
