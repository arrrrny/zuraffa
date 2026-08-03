import 'package:zuraffa/zuraffa.dart';

import '../../domain/entities/todo.dart';
import 'todo_datasource.dart';

/// Hive-backed local datasource for [Todo] entities.
///
/// All queries run against a [Box<Todo>], leveraging zorphy-generated
/// [Filter] extensions on [Iterable] and [TodoFields] descriptors
/// for type-safe filtering and sorting.
///
/// The `watchList` method listens to the Hive box's change stream
/// and re-emits the filtered/sorted list on every write — this is
/// what drives reactive UI updates via [WatchTodoListUseCase].
class TodoLocalDataSource
    with Loggable, FailureHandler
    implements TodoDataSource {
  TodoLocalDataSource(this._box);

  final Box<Todo> _box;

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
      orElse: () => throw notFoundFailure('Todo not found'),
    );
    final updated = params.data.applyTo(existing);
    await _box.put(updated.id, updated);
    return updated;
  }

  @override
  Future<void> delete(DeleteParams<int> params) async {
    final existing = _box.values.firstWhere(
      (item) => item.id == params.id,
      orElse: () => throw notFoundFailure('Todo not found'),
    );
    await _box.delete(existing.id);
  }

  @override
  Stream<Todo> watch(QueryParams<Todo> params) async* {
    yield _box.values.query(params);
  }

  @override
  Stream<List<Todo>> watchList(ListQueryParams<Todo> params) async* {
    yield _box.values.filter(params.filter).orderBy(params.sort);
    yield* _box.watch().map(
      (_) => _box.values.filter(params.filter).orderBy(params.sort),
    );
  }
}
