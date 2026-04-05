import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zuraffa/zuraffa.dart';

import '../../../../lib/src/domain/entities/concert/concert.dart';
import '../../../../lib/src/domain/repositories/concert_repository.dart';
import '../../../../lib/src/domain/usecases/concert/get_concert_list_usecase.dart';

class MockConcertRepository extends Mock implements ConcertRepository {}

class MockConcert extends Mock implements Concert {}

void main() {
  late GetConcertListUseCase useCase;
  late MockConcertRepository mockRepository;
  setUp(() {
    registerFallbackValue(const ListQueryParams<Concert>());
    mockRepository = MockConcertRepository();
    useCase = GetConcertListUseCase(mockRepository);
  });
  group('GetConcertListUseCase', () {
    final tConcert = MockConcert();
    final tConcertList = [tConcert];
    test('should call repository.getList and return result', () async {
      when(
        () => mockRepository.getList(any()),
      ).thenAnswer((_) async => tConcertList);
      final result = await useCase.call(ListQueryParams<Concert>());
      verify(() => mockRepository.getList(any())).called(1);
      expect(result.isSuccess, true);
      expect(result.getOrElse(() => throw (Exception())), equals(tConcertList));
    });
    test('should return Failure when repository throws', () async {
      final exception = Exception('Error');
      when(() => mockRepository.getList(any())).thenThrow(exception);
      final result = await useCase.call(ListQueryParams<Concert>());
      verify(() => mockRepository.getList(any())).called(1);
      expect(result.isFailure, true);
    });
  });
}
