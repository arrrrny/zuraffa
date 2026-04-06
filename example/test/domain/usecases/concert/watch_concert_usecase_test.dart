import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zuraffa/zuraffa.dart';

import 'package:example/src/domain/entities/concert/concert.dart';
import 'package:example/src/domain/repositories/concert_repository.dart';
import 'package:example/src/domain/usecases/concert/watch_concert_usecase.dart';

class MockConcertRepository extends Mock implements ConcertRepository {}

class MockConcert extends Mock implements Concert {}

void main() {
  late WatchConcertUseCase useCase;
  late MockConcertRepository mockRepository;
  setUp(() {
    registerFallbackValue(const QueryParams<Concert>());
    mockRepository = MockConcertRepository();
    useCase = WatchConcertUseCase(mockRepository);
  });
  group('WatchConcertUseCase', () {
    final tConcert = MockConcert();
    test('should emit values from repository stream', () async {
      when(
        () => mockRepository.watch(any()),
      ).thenAnswer((_) => Stream.value(tConcert));
      final result = useCase.call(
        const QueryParams<Concert>(filter: Eq(ConcertFields.id, '1')),
      );
      await expectLater(
        result,
        emits(isA<Success>().having((s) => s.value, 'value', equals(tConcert))),
      );
      verify(() => mockRepository.watch(any())).called(1);
    });
    test('should emit Failure when repository stream errors', () async {
      final exception = Exception('Stream Error');
      when(
        () => mockRepository.watch(any()),
      ).thenAnswer((_) => Stream.error(exception));
      final result = useCase.call(
        const QueryParams<Concert>(filter: Eq(ConcertFields.id, '1')),
      );
      await expectLater(result, emits(isA<Failure>()));
      verify(() => mockRepository.watch(any())).called(1);
    });
  });
}
