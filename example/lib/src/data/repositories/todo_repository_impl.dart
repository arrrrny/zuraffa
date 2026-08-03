import 'dart:async';

import 'package:zuraffa/zuraffa.dart';

import '../../domain/entities/todo.dart';
import '../../domain/repositories/todo_repository.dart';
import '../datasources/todo_datasource.dart';

/// Implementation of [TodoRepository] with local-only storage.
///
/// For this example, both read and write paths go through a single
/// [TodoDataSource] (the local Hive-backed one). In a production app,
/// you would inject a remote datasource and add cache-aside logic.
///
/// This is intentionally simple — the focus is on demonstrating
/// zuraffa's Controller/Presenter/State pattern and zorphy's entity
/// generation, not on building a full offline-first sync layer.
class TodoRepositoryImpl
    with Loggable, FailureHandler
    implements TodoRepository {
  TodoRepositoryImpl(this._dataSource);

  final TodoDataSource _dataSource;

  @override
  Future<Todo> get(QueryParams<Todo> params) => _dataSource.get(params);

  @override
  Future<List<Todo>> getList(ListQueryParams<Todo> params) =>
      _dataSource.getList(params);

  @override
  Future<Todo> create(Todo todo) => _dataSource.create(todo);

  @override
  Future<Todo> update(UpdateParams<int, TodoPatch> params) =>
      _dataSource.update(params);

  @override
  Future<void> delete(DeleteParams<int> params) => _dataSource.delete(params);

  @override
  Stream<Todo> watch(QueryParams<Todo> params) => _dataSource.watch(params);

  @override
  Stream<List<Todo>> watchList(ListQueryParams<Todo> params) =>
      _dataSource.watchList(params);
}
