import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:example/src/domain/entities/todo/todo.dart';
import 'package:example/src/domain/repositories/todo_repository.dart';
import 'package:example/src/domain/usecases/todo/watch_todo_list_usecase.dart';

class MockTodoRepository extends Mock implements TodoRepository {}

class FakeListQueryParams extends Fake implements ListQueryParams {}

void main() {
  late WatchTodoListUseCase useCase;
  late MockTodoRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(FakeListQueryParams());
  });

  setUp(() {
    mockRepository = MockTodoRepository();
    useCase = WatchTodoListUseCase(mockRepository);
  });

  group('WatchTodoListUseCase', () {
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

    test('should call repository.watchList and return stream', () async {
      // Arrange
      const params = ListQueryParams<Todo>();
      final stream = Stream.fromIterable([testTodos]);
      when(() => mockRepository.watchList(params)).thenAnswer((_) => stream);

      // Act
      final result = useCase(params);

      // Assert
      expect(result, isA<Stream<Result<List<Todo>, AppFailure>>>());

      // Verify stream emits correct value
      await expectLater(
        result,
        emits(isA<Success<List<Todo>, AppFailure>>()
            .having((s) => s.value, 'value', testTodos)),
      );

      verify(() => mockRepository.watchList(params)).called(1);
    });

    test('should return stream that emits multiple lists', () async {
      // Arrange
      const params = ListQueryParams<Todo>();
      final updatedTodos = [
        ...testTodos,
        Todo(
          id: 3,
          title: 'Todo 3',
          isCompleted: false,
          createdAt: DateTime(2026, 1, 29),
        ),
      ];
      final stream = Stream.fromIterable([testTodos, updatedTodos]);
      when(() => mockRepository.watchList(params)).thenAnswer((_) => stream);

      // Act
      final result = useCase(params);

      // Assert
      await expectLater(
        result,
        emitsInOrder([
          isA<Success<List<Todo>, AppFailure>>()
              .having((s) => s.value, 'value', testTodos),
          isA<Success<List<Todo>, AppFailure>>()
              .having((s) => s.value, 'value', updatedTodos),
        ]),
      );
    });

    test('should return empty list stream when no todos exist', () async {
      // Arrange
      const params = ListQueryParams<Todo>();
      final stream = Stream.fromIterable([<Todo>[]]);
      when(() => mockRepository.watchList(params)).thenAnswer((_) => stream);

      // Act
      final result = useCase(params);

      // Assert
      await expectLater(
        result,
        emits(
          isA<Success<List<Todo>, AppFailure>>()
              .having((s) => s.value, 'value', isEmpty),
        ),
      );
    });

    test('should return stream that emits error when repository fails',
        () async {
      // Arrange
      const params = ListQueryParams<Todo>();
      final exception = Exception('Watch list error');
      final stream = Stream<List<Todo>>.error(exception);
      when(() => mockRepository.watchList(params)).thenAnswer((_) => stream);

      // Act
      final result = useCase(params);

      // Assert
      await expectLater(
        result,
        emits(
          isA<Failure<List<Todo>, AppFailure>>()
              .having((f) => f.error, 'error', isA<UnknownFailure>()),
        ),
      );
    });

    test('should respect cancel token', () async {
      // Arrange
      const params = ListQueryParams<Todo>();
      final cancelToken = CancelToken();
      cancelToken.cancel();

      // Act
      final result = useCase(params, cancelToken: cancelToken);

      // Assert
      await expectLater(
        result,
        emits(
          isA<Failure<List<Todo>, AppFailure>>()
              .having((f) => f.error, 'error', isA<CancellationFailure>()),
        ),
      );
      verifyNever(() => mockRepository.watchList(any()));
    });
  });
}
