import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:example/src/domain/entities/todo/todo.dart';
import 'package:example/src/domain/repositories/todo_repository.dart';
import 'package:example/src/domain/usecases/todo/get_todo_list_usecase.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

class FakeListQueryParams extends Fake implements ListQueryParams {}

void main() {
  late GetTodoListUseCase useCase;
  late MockTodoRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(FakeListQueryParams());
  });

  setUp(() {
    mockRepository = MockTodoRepository();
    useCase = GetTodoListUseCase(mockRepository);
  });

  group('GetTodoListUseCase', () {
    final testTodos = [
      Todo(
        id: 1,
        title: 'Todo 1',
        isCompleted: false,
        createdAt: DateTime(2026, 1, 31),
      ),
      Todo(
        id: 2,
        title: 'Todo 2',
        isCompleted: true,
        createdAt: DateTime(2026, 1, 30),
      ),
    ];

    test('should call repository.getList with correct parameters', () async {
      // Arrange
      const params = ListQueryParams<Todo>();
      when(() => mockRepository.getList(params))
          .thenAnswer((_) async => testTodos);

      // Act
      final result = await useCase(params);

      // Assert
      verify(() => mockRepository.getList(params)).called(1);
      expect(result.isSuccess, true);
      expect(result.getOrElse(() => throw Exception()), equals(testTodos));
    });

    test('should return empty list when no todos exist', () async {
      // Arrange
      const params = ListQueryParams<Todo>();
      when(() => mockRepository.getList(params)).thenAnswer((_) async => []);

      // Act
      final result = await useCase(params);

      // Assert
      verify(() => mockRepository.getList(params)).called(1);
      expect(result.isSuccess, true);
      expect(result.getOrElse(() => throw Exception()), isEmpty);
    });

    test('should return Failure when repository throws', () async {
      // Arrange
      const params = ListQueryParams<Todo>();
      final exception = Exception('Database error');
      when(() => mockRepository.getList(params)).thenThrow(exception);

      // Act
      final result = await useCase(params);

      // Assert
      verify(() => mockRepository.getList(params)).called(1);
      expect(result.isFailure, true);
    });

    test('should return CancellationFailure when cancelled', () async {
      // Arrange
      const params = ListQueryParams<Todo>();
      final cancelToken = CancelToken();
      cancelToken.cancel();

      // Act
      final result = await useCase(params, cancelToken: cancelToken);

      // Assert
      expect(result.isFailure, true);
      expect(result.getFailureOrNull(), isA<CancellationFailure>());
      verifyNever(() => mockRepository.getList(any()));
    });
  });
}
