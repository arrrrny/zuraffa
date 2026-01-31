import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:example/src/domain/entities/todo/todo.dart';
import 'package:example/src/domain/repositories/todo_repository.dart';
import 'package:example/src/domain/usecases/todo/create_todo_usecase.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

class FakeTodo extends Fake implements Todo {}

void main() {
  late CreateTodoUseCase useCase;
  late MockTodoRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(FakeTodo());
  });

  setUp(() {
    mockRepository = MockTodoRepository();
    useCase = CreateTodoUseCase(mockRepository);
  });

  group('CreateTodoUseCase', () {
    final testTodo = Todo(
      id: 1,
      title: 'Test Todo',
      isCompleted: false,
      createdAt: DateTime(2026, 1, 31),
    );

    test('should call repository.create with correct parameters', () async {
      // Arrange
      when(() => mockRepository.create(testTodo))
          .thenAnswer((_) async => testTodo);

      // Act
      final result = await useCase(testTodo);

      // Assert
      verify(() => mockRepository.create(testTodo)).called(1);
      expect(result.isSuccess, true);
      expect(result.getOrElse(() => throw Exception()), equals(testTodo));
    });

    test('should return Failure when repository throws', () async {
      // Arrange
      final exception = Exception('Create failed');
      when(() => mockRepository.create(testTodo)).thenThrow(exception);

      // Act
      final result = await useCase(testTodo);

      // Assert
      verify(() => mockRepository.create(testTodo)).called(1);
      expect(result.isFailure, true);
    });

    test('should return CancellationFailure when cancelled', () async {
      // Arrange
      final cancelToken = CancelToken();
      cancelToken.cancel();

      // Act
      final result = await useCase(testTodo, cancelToken: cancelToken);

      // Assert
      expect(result.isFailure, true);
      expect(result.getFailureOrNull(), isA<CancellationFailure>());
      verifyNever(() => mockRepository.create(any()));
    });
  });
}
