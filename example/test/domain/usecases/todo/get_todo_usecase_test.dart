import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:example/src/domain/entities/todo/todo.dart';
import 'package:example/src/domain/repositories/todo_repository.dart';
import 'package:example/src/domain/usecases/todo/get_todo_usecase.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

void main() {
  late GetTodoUseCase useCase;
  late MockTodoRepository mockRepository;

  setUp(() {
    mockRepository = MockTodoRepository();
    useCase = GetTodoUseCase(mockRepository);
  });

  group('GetTodoUseCase', () {
    const testId = '1';
    final testTodo = Todo(
      id: 1,
      title: 'Test Todo',
      isCompleted: false,
      createdAt: DateTime(2026, 1, 31),
    );

    test('should call repository.get with correct ID', () async {
      // Arrange
      when(() => mockRepository.get(testId)).thenAnswer((_) async => testTodo);

      // Act
      final result = await useCase(QueryParams(testId));

      // Assert
      verify(() => mockRepository.get(testId)).called(1);
      expect(result.isSuccess, true);
      expect(result.getOrElse(() => throw Exception()), equals(testTodo));
    });

    test('should return Failure when repository throws', () async {
      // Arrange
      final exception = Exception('Not found');
      when(() => mockRepository.get(testId)).thenThrow(exception);

      // Act
      final result = await useCase(QueryParams(testId));

      // Assert
      verify(() => mockRepository.get(testId)).called(1);
      expect(result.isFailure, true);
    });

    test('should return CancellationFailure when cancelled', () async {
      // Arrange
      final cancelToken = CancelToken();
      cancelToken.cancel();

      // Act
      final result =
          await useCase(QueryParams(testId), cancelToken: cancelToken);

      // Assert
      expect(result.isFailure, true);
      expect(result.getFailureOrNull(), isA<CancellationFailure>());
      verifyNever(() => mockRepository.get(any()));
    });
  });
}
