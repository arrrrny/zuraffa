import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:example/src/domain/entities/todo/todo.dart';
import 'package:example/src/domain/repositories/todo_repository.dart';
import 'package:example/src/domain/usecases/todo/watch_todo_usecase.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

void main() {
  late WatchTodoUseCase useCase;
  late MockTodoRepository mockRepository;

  setUp(() {
    mockRepository = MockTodoRepository();
    useCase = WatchTodoUseCase(mockRepository);
  });

  group('WatchTodoUseCase', () {
    const testId = '1';
    final testTodo = Todo(
      id: 1,
      title: 'Test Todo',
      isCompleted: false,
      createdAt: DateTime(2026, 1, 31),
    );

    test('should call repository.watch with correct ID and return stream', () async {
      // Arrange
      final stream = Stream.fromIterable([testTodo]);
      when(() => mockRepository.watch(testId)).thenAnswer((_) => stream);

      // Act
      final result = useCase(QueryParams(testId));

      // Assert
      expect(result, isA<Stream<Result<Todo, AppFailure>>>());
      
      // Verify stream emits correct value wrapped in Success
      await expectLater(
        result, 
        emits(isA<Success<Todo, AppFailure>>().having(
          (s) => s.value, 'value', equals(testTodo)
        ))
      );
      verify(() => mockRepository.watch(testId)).called(1);
    });

    test('should return stream that emits multiple values', () async {
      // Arrange
      final updatedTodo = testTodo.copyWith(isCompleted: true);
      final stream = Stream.fromIterable([testTodo, updatedTodo]);
      when(() => mockRepository.watch(testId)).thenAnswer((_) => stream);

      // Act
      final result = useCase(QueryParams(testId));

      // Assert
      await expectLater(
        result, 
        emitsInOrder([
          isA<Success<Todo, AppFailure>>().having((s) => s.value, 'value', equals(testTodo)),
          isA<Success<Todo, AppFailure>>().having((s) => s.value, 'value', equals(updatedTodo)),
        ])
      );
    });

    test('should return Failure when repository stream emits error', () async {
      // Arrange
      final exception = Exception('Watch error');
      final stream = Stream<Todo>.error(exception);
      when(() => mockRepository.watch(testId)).thenAnswer((_) => stream);

      // Act
      final result = useCase(QueryParams(testId));

      // Assert
      await expectLater(
        result, 
        emits(isA<Failure<Todo, AppFailure>>())
      );
    });

    test('should return CancellationFailure when cancelled', () async {
      // Arrange
      final cancelToken = CancelToken();
      cancelToken.cancel();

      // Act
      final result = useCase(QueryParams(testId), cancelToken: cancelToken);

      // Assert
      await expectLater(
        result, 
        emits(isA<Failure<Todo, AppFailure>>())
      );
      verifyNever(() => mockRepository.watch(any()));
    });
  });
}
