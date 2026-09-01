// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/todo/todo.dart';

abstract class TodoDataSource with Loggable, FailureHandler {
  Future<Todo> create(Todo todo);
  Future<Todo> get(QueryParams<Todo> params);
  Future<List<Todo>> getList(ListQueryParams<Todo> params);
  Future<Todo> update(UpdateParams<int, TodoPatch> params);
  Future<void> delete(DeleteParams<int> params);
  Stream<Todo> watch(QueryParams<Todo> params);
  Stream<List<Todo>> watchList(ListQueryParams<Todo> params);
}

// END GENERATED
