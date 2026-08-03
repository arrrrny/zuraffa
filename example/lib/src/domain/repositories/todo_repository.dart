import 'package:zuraffa/zuraffa.dart';

import '../entities/todo.dart';

/// Contract for todo data operations.
///
/// This abstract class lives in the domain layer — it knows nothing
/// about Hive, HTTP, or any infrastructure. The data layer provides
/// [DataTodoRepository] as the concrete implementation.
///
/// Method signatures use zuraffa's built-in query parameter types:
/// - [QueryParams] for single-entity reads with optional [Eq] / [And] filters.
/// - [ListQueryParams] for list reads with filter, sort, pagination.
/// - [UpdateParams] for patch-based partial updates via [TodoPatch].
/// - [DeleteParams] for deletion by id.
///
/// The `watch*` variants return [Stream]s for reactive UI updates.
abstract class TodoRepository {
  Future<Todo> get(QueryParams<Todo> params);
  Future<List<Todo>> getList(ListQueryParams<Todo> params);
  Future<Todo> create(Todo todo);
  Future<Todo> update(UpdateParams<int, TodoPatch> params);
  Future<void> delete(DeleteParams<int> params);
  Stream<Todo> watch(QueryParams<Todo> params);
  Stream<List<Todo>> watchList(ListQueryParams<Todo> params);
}
