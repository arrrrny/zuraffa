import 'dart:async';

import 'package:zuraffa/zuraffa.dart';

import '../../domain/entities/todo/todo.dart';
import '../../domain/repositories/todo_repository.dart';
import '../data_sources/todo/todo_data_source.dart';
import '../data_sources/todo/todo_local_data_source.dart';

class DataTodoRepository
    with Loggable, FailureHandler
    implements TodoRepository {
  DataTodoRepository(
    this._remoteDataSource,
    this._localDataSource,
    this._cachePolicy,
  );

  final TodoDataSource _remoteDataSource;

  final TodoLocalDataSource _localDataSource;

  final CachePolicy _cachePolicy;

  @override
  Future<Todo> get(QueryParams<Todo> params) async {
    if (await _cachePolicy.isValid('todo_cache')) {
      try {
        return await _localDataSource.get(params);
      } catch (_) {}
    }
    final data = await _remoteDataSource.get(params);
    await _localDataSource.save(data);
    await _cachePolicy.markFresh('todo_cache');
    return data;
  }

  @override
  Future<List<Todo>> getList(ListQueryParams<Todo> params) async {
    final listCacheKey = 'todo_cache_${params.hashCode}';
    if (await _cachePolicy.isValid(listCacheKey)) {
      try {
        return await _localDataSource.getList(params);
      } catch (_) {}
    }
    final data = await _remoteDataSource.getList(params);
    await _localDataSource.saveAll(data);
    await _cachePolicy.markFresh(listCacheKey);
    return data;
  }

  @override
  Future<Todo> create(Todo todo) async {
    final data = await _remoteDataSource.create(todo);
    await _localDataSource.save(data);
    await _cachePolicy.invalidate('todo_cache');
    return data;
  }

  @override
  Future<Todo> update(UpdateParams<int, TodoPatch> params) async {
    final data = await _remoteDataSource.update(params);
    await _localDataSource.save(data);
    await _cachePolicy.invalidate('todo_cache');
    return data;
  }

  @override
  Future<void> delete(DeleteParams<int> params) async {
    await _remoteDataSource.delete(params);
    await _localDataSource.delete(params);
    await _cachePolicy.invalidate('todo_cache');
  }

  @override
  Stream<Todo> watch(QueryParams<Todo> params) {
    return _remoteDataSource.watch(params);
  }

  @override
  Stream<List<Todo>> watchList(ListQueryParams<Todo> params) {
    return _remoteDataSource.watchList(params);
  }
}
