import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zuraffa/zuraffa.dart';

import '../../../../lib/src/domain/entities/concert/concert.dart';
import '../../../../lib/src/domain/repositories/concert_repository.dart';
import '../../../../lib/src/domain/usecases/concert/update_concert_usecase.dart';

class MockConcertRepository extends Mock implements ConcertRepository {}

class MockConcert extends Mock implements Concert {}

void main() {
  late UpdateConcertUseCase useCase;
  late MockConcertRepository mockRepository;
  setUp(() {
    registerFallbackValue(
      UpdateParams<String, ConcertPatch>(id: '1', data: ConcertPatch()),
    );
    mockRepository = MockConcertRepository();
    useCase = UpdateConcertUseCase(mockRepository);
  });
  group('UpdateConcertUseCase', () {
    final tConcert = MockConcert();
    test('should call repository.update and return result', () async {
      when(
        () => mockRepository.update(any()),
      ).thenAnswer((_) async => tConcert);
      final result = await useCase.call(
        UpdateParams<String, ConcertPatch>(id: '1', data: ConcertPatch()),
      );
      verify(() => mockRepository.update(any())).called(1);
      expect(result.isSuccess, true);
      expect(result.getOrElse(() => throw (Exception())), equals(tConcert));
    });
    test('should return Failure when repository throws', () async {
      final exception = Exception('Error');
      when(() => mockRepository.update(any())).thenThrow(exception);
      final result = await useCase.call(
        UpdateParams<String, ConcertPatch>(id: '1', data: ConcertPatch()),
      );
      verify(() => mockRepository.update(any())).called(1);
      expect(result.isFailure, true);
    });
  });
}
