import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/todo/todo.dart';
import 'todo_data_source.dart';

class TodoRemoteDataSource
    with Loggable, FailureHandler
    implements TodoDataSource {
  @override
  Future<Todo> get(QueryParams<Todo> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<List<Todo>> getList(ListQueryParams<Todo> params) async {
    throw UnimplementedError('Implement remote getList');
  }

  @override
  Future<Todo> create(Todo todo) async {
    throw UnimplementedError('Implement remote create');
  }

  @override
  Future<Todo> update(UpdateParams<int, TodoPatch> params) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<void> delete(DeleteParams<int> params) async {
    throw UnimplementedError('Implement remote delete');
  }

  @override
  Stream<Todo> watch(QueryParams<Todo> params) {
    throw UnimplementedError('Implement remote watch');
  }

  @override
  Stream<List<Todo>> watchList(ListQueryParams<Todo> params) {
    throw UnimplementedError('Implement remote watchList');
  }
}
