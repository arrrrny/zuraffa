import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/todo/todo.dart';

abstract class TodoDataSource with Loggable, FailureHandler {
  Future<Todo> get(QueryParams<Todo> params) {
    throw UnimplementedError();
  }

  Future<List<Todo>> getList(ListQueryParams<Todo> params) {
    throw UnimplementedError();
  }

  Future<Todo> create(Todo todo) {
    throw UnimplementedError();
  }

  Future<Todo> update(UpdateParams<int, TodoPatch> params) {
    throw UnimplementedError();
  }

  Future<void> delete(DeleteParams<int> params) {
    throw UnimplementedError();
  }

  Stream<Todo> watch(QueryParams<Todo> params) {
    throw UnimplementedError();
  }

  Stream<List<Todo>> watchList(ListQueryParams<Todo> params) {
    throw UnimplementedError();
  }
}
