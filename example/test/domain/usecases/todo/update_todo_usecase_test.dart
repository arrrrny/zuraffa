import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:example/src/domain/entities/todo/todo.dart';
import 'package:example/src/domain/repositories/todo_repository.dart';
import 'package:example/src/domain/usecases/todo/update_todo_usecase.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

class FakeUpdateParams extends Fake implements UpdateParams<Map<String, dynamic>> {}

void main() {
  late UpdateTodoUseCase useCase;
  late MockTodoRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(FakeUpdateParams());
  });

  setUp(() {
    mockRepository = MockTodoRepository();
    useCase = UpdateTodoUseCase(mockRepository);
  });

  group('UpdateTodoUseCase', () {
    final testTodo = Todo(
      id: 1,
      title: 'Updated Todo',
      isCompleted: true,
      createdAt: DateTime(2026, 1, 31),
    );

    final updateParams = UpdateParams<Partial<Todo>>(
      id: '1',
      data: testTodo.toJson(),
    );

    test('should call repository.update with correct parameters', () async {
      // Arrange
      when(() => mockRepository.update(updateParams))
          .thenAnswer((_) async => testTodo);

      // Act
      final result = await useCase(updateParams);

      // Assert
      verify(() => mockRepository.update(updateParams)).called(1);
      expect(result.isSuccess, true);
      expect(result.getOrElse(() => throw Exception()), equals(testTodo));
    });

    test('should return Failure when repository throws', () async {
      // Arrange
      final exception = Exception('Update failed');
      when(() => mockRepository.update(updateParams)).thenThrow(exception);

      // Act
      final result = await useCase(updateParams);

      // Assert
      verify(() => mockRepository.update(updateParams)).called(1);
      expect(result.isFailure, true);
    });

    test('should return CancellationFailure when cancelled', () async {
      // Arrange
      final cancelToken = CancelToken();
      cancelToken.cancel();

      // Act
      final result = await useCase(updateParams, cancelToken: cancelToken);

      // Assert
      expect(result.isFailure, true);
      expect(result.getFailureOrNull(), isA<CancellationFailure>());
      verifyNever(() => mockRepository.update(any()));
    });
  });
}
