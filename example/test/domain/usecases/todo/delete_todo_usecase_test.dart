import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:example/src/domain/entities/todo/todo.dart';
import 'package:example/src/domain/repositories/todo_repository.dart';
import 'package:example/src/domain/usecases/todo/delete_todo_usecase.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

class FakeDeleteParams extends Fake implements DeleteParams<Todo> {}

void main() {
  late DeleteTodoUseCase useCase;
  late MockTodoRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(FakeDeleteParams());
  });

  setUp(() {
    mockRepository = MockTodoRepository();
    useCase = DeleteTodoUseCase(mockRepository);
  });

  group('DeleteTodoUseCase', () {
    final testTodo = Todo(
      id: 1,
      title: 'Todo to Delete',
      isCompleted: false,
      createdAt: DateTime(2026, 1, 31),
    );

    final deleteParams = DeleteParams<Todo>(
      '1',
    );

    test('should call repository.delete with correct parameters', () async {
      // Arrange
      when(() => mockRepository.delete(deleteParams)).thenAnswer((_) async {});

      // Act
      final result = await useCase(deleteParams);

      // Assert
      verify(() => mockRepository.delete(deleteParams)).called(1);
      expect(result.isSuccess, true);
    });

    test('should return Failure when repository throws', () async {
      // Arrange
      final exception = Exception('Delete failed');
      when(() => mockRepository.delete(deleteParams)).thenThrow(exception);

      // Act
      final result = await useCase(deleteParams);

      // Assert
      verify(() => mockRepository.delete(deleteParams)).called(1);
      expect(result.isFailure, true);
    });

    test('should return CancellationFailure when cancelled', () async {
      // Arrange
      final cancelToken = CancelToken();
      cancelToken.cancel();

      // Act
      final result = await useCase(deleteParams, cancelToken: cancelToken);

      // Assert
      expect(result.getFailureOrNull(), isA<CancellationFailure>());
      verifyNever(() => mockRepository.delete(any()));
    });
  });
}
