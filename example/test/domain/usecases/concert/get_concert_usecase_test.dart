import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zuraffa/zuraffa.dart';

import 'package:example/src/domain/entities/concert/concert.dart';
import 'package:example/src/domain/repositories/concert_repository.dart';
import 'package:example/src/domain/usecases/concert/get_concert_usecase.dart';

class MockConcertRepository extends Mock implements ConcertRepository {}

class MockConcert extends Mock implements Concert {}

void main() {
  late GetConcertUseCase useCase;
  late MockConcertRepository mockRepository;
  setUp(() {
    registerFallbackValue(const QueryParams<Concert>());
    mockRepository = MockConcertRepository();
    useCase = GetConcertUseCase(mockRepository);
  });
  group('GetConcertUseCase', () {
    final tConcert = MockConcert();
    test('should call repository.get and return result', () async {
      when(() => mockRepository.get(any())).thenAnswer((_) async => tConcert);
      final result = await useCase.call(
        const QueryParams<Concert>(filter: Eq(ConcertFields.id, '1')),
      );
      verify(() => mockRepository.get(any())).called(1);
      expect(result.isSuccess, true);
      expect(result.getOrElse(() => throw (Exception())), equals(tConcert));
    });
    test('should return Failure when repository throws', () async {
      final exception = Exception('Error');
      when(() => mockRepository.get(any())).thenThrow(exception);
      final result = await useCase.call(
        const QueryParams<Concert>(filter: Eq(ConcertFields.id, '1')),
      );
      verify(() => mockRepository.get(any())).called(1);
      expect(result.isFailure, true);
    });
  });
}
