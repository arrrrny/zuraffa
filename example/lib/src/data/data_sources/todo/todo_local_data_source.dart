import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/todo/todo.dart';
import 'todo_data_source.dart';

class TodoLocalDataSource
    with Loggable, FailureHandler
    implements TodoDataSource {
  TodoLocalDataSource(this._box);

  final Box<Todo> _box;

  Future<Todo> save(Todo todo) async {
    await _box.put(todo.id, todo);
    return todo;
  }

  Future<void> saveAll(List<Todo> items) async {
    final map = {for (var item in items) item.id: item};
    await _box.putAll(map);
  }

  Future<void> clear() async {
    await _box.clear();
  }

  @override
  Future<Todo> get(QueryParams<Todo> params) async {
    return _box.values.query(params);
  }

  @override
  Future<List<Todo>> getList(ListQueryParams<Todo> params) async {
    return _box.values.filter(params.filter).orderBy(params.sort);
  }

  @override
  Future<Todo> create(Todo todo) async {
    await _box.put(todo.id, todo);
    return todo;
  }

  @override
  Future<Todo> update(UpdateParams<int, TodoPatch> params) async {
    final existing = _box.values.firstWhere(
      (item) => item.id == params.id,
      orElse: () => throw notFoundFailure('Todo not found in cache'),
    );
    final updated = params.data.applyTo(existing);
    await _box.put(updated.id, updated);
    return updated;
  }

  @override
  Future<void> delete(DeleteParams<int> params) async {
    final existing = _box.values.firstWhere(
      (item) => item.id == params.id,
      orElse: () => throw notFoundFailure('Todo not found in cache'),
    );
    await _box.delete(existing.id);
  }

  @override
  Stream<Todo> watch(QueryParams<Todo> params) async* {
    yield _box.values.query(params);
  }

  @override
  Stream<List<Todo>> watchList(ListQueryParams<Todo> params) async* {
    final existing = _box.values.filter(params.filter).orderBy(params.sort);
    yield existing;
    yield* _box.watch().map(
          (_) => _box.values.filter(params.filter).orderBy(params.sort),
        );
  }
}
