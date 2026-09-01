// GENERATED - DO NOT EDIT
import 'package:example/src/data/datasources/todo/todo_datasource.dart';
import 'package:example/src/data/datasources/todo/todo_mock_datasource.dart';
import 'package:example/src/data/repositories/data_todo_repository.dart';
import 'package:example/src/domain/entities/todo/todo.dart';
import 'package:example/src/domain/usecases/todo/get_todo_list_usecase.dart';
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
  late GetTodoListUseCase useCase;
  late GetTodoListUseCase throwingUseCase;
  late DataTodoRepository repository;
  late DataTodoRepository throwingRepository;
  late TodoMockDataSource mockDataSource;
  late ThrowingTodoDataSource throwingDataSource;
  setUp(() {
    mockDataSource = TodoMockDataSource();
    throwingDataSource = ThrowingTodoDataSource();
    repository = DataTodoRepository(mockDataSource);
    throwingRepository = DataTodoRepository(throwingDataSource);
    useCase = GetTodoListUseCase(repository);
    throwingUseCase = GetTodoListUseCase(throwingRepository);
  });
  group('GetTodoListUseCase', () {
    test('should call repository.getList and return result', () async {
      final result = await useCase.call(ListQueryParams<Todo>());
      expect(result.isSuccess, true);
      expect(
        result.getOrElse(() => throw (Exception('not success'))),
        isA<List<Todo>>(),
      );
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(ListQueryParams<Todo>());
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
