// GENERATED - DO NOT EDIT
import 'package:example/src/data/datasources/todo/todo_datasource.dart';
import 'package:example/src/data/datasources/todo/todo_mock_datasource.dart';
import 'package:example/src/data/mock/todo_mock_data.dart';
import 'package:example/src/data/repositories/data_todo_repository.dart';
import 'package:example/src/domain/entities/todo/todo.dart';
import 'package:example/src/domain/usecases/todo/delete_todo_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/mock.dart';

class ThrowingTodoDataSource
    with Loggable, FailureHandler
    implements TodoDataSource {
  @override
  Future<Todo> get(QueryParams<Todo> params) {
    throw (Exception('ThrowingTodoDataSource.get'));
  }

  @override
  Future<List<Todo>> getList(ListQueryParams<Todo> params) {
    throw (Exception('ThrowingTodoDataSource.getList'));
  }

  @override
  Future<Todo> create(Todo entity) {
    throw (Exception('ThrowingTodoDataSource.create'));
  }

  @override
  Future<Todo> update(UpdateParams<int, TodoPatch> params) {
    throw (Exception('ThrowingTodoDataSource.update'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<int> params) {
    throw (Exception('ThrowingTodoDataSource.delete'));
  }

  @override
  Stream<Todo> watch(QueryParams<Todo> params) {
    throw (Exception('ThrowingTodoDataSource.watch'));
  }

  @override
  Stream<List<Todo>> watchList(ListQueryParams<Todo> params) {
    throw (Exception('ThrowingTodoDataSource.watchList'));
  }
}

void main() {
  late DeleteTodoUseCase useCase;
  late DeleteTodoUseCase throwingUseCase;
  late DataTodoRepository repository;
  late DataTodoRepository throwingRepository;
  late TodoMockDataSource mockDataSource;
  late ThrowingTodoDataSource throwingDataSource;
  setUp(() {
    mockDataSource = TodoMockDataSource();
    throwingDataSource = ThrowingTodoDataSource();
    repository = DataTodoRepository(mockDataSource);
    throwingRepository = DataTodoRepository(throwingDataSource);
    useCase = DeleteTodoUseCase(repository);
    throwingUseCase = DeleteTodoUseCase(throwingRepository);
  });
  group('DeleteTodoUseCase', () {
    final tTodo = TodoMockData.sampleTodo;
    test('should call repository.delete and return result', () async {
      final result = await useCase.call(DeleteParams<int>(id: tTodo.id));
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        DeleteParams<int>(id: tTodo.id),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
