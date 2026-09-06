// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/zik_zak_score/zik_zak_score_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/zik_zak_score/zik_zak_score_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/zik_zak_score_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_zik_zak_score_repository.dart';
import 'package:zikzak_demo/src/domain/entities/zik_zak_score/zik_zak_score.dart';
import 'package:zikzak_demo/src/domain/repositories/zik_zak_score_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/zik_zak_score/update_zik_zak_score_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingZikZakScoreDataSource
    with Loggable, FailureHandler
    implements ZikZakScoreDataSource {
  @override
  Future<ZikZakScore> get(QueryParams<ZikZakScore> params) {
    throw (Exception('ThrowingZikZakScoreDataSource.get'));
  }

  @override
  Future<List<ZikZakScore>> getList(ListQueryParams<ZikZakScore> params) {
    throw (Exception('ThrowingZikZakScoreDataSource.getList'));
  }

  @override
  Future<ZikZakScore> create(ZikZakScore entity) {
    throw (Exception('ThrowingZikZakScoreDataSource.create'));
  }

  @override
  Future<ZikZakScore> update(UpdateParams<String, ZikZakScorePatch> params) {
    throw (Exception('ThrowingZikZakScoreDataSource.update'));
  }

  @override
  Future<ZikZakScore> toggle(
    ToggleParams<String, Field<ZikZakScore, dynamic>> params,
  ) {
    throw (Exception('ThrowingZikZakScoreDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingZikZakScoreDataSource.delete'));
  }

  @override
  Stream<ZikZakScore> watch(QueryParams<ZikZakScore> params) {
    throw (Exception('ThrowingZikZakScoreDataSource.watch'));
  }

  @override
  Stream<List<ZikZakScore>> watchList(ListQueryParams<ZikZakScore> params) {
    throw (Exception('ThrowingZikZakScoreDataSource.watchList'));
  }
}

void main() {
  late UpdateZikZakScoreUseCase useCase;
  late UpdateZikZakScoreUseCase throwingUseCase;
  late DataZikZakScoreRepository repository;
  late DataZikZakScoreRepository throwingRepository;
  late ZikZakScoreMockDataSource mockDataSource;
  late ThrowingZikZakScoreDataSource throwingDataSource;
  setUp(() {
    mockDataSource = ZikZakScoreMockDataSource();
    throwingDataSource = ThrowingZikZakScoreDataSource();
    repository = DataZikZakScoreRepository(mockDataSource);
    throwingRepository = DataZikZakScoreRepository(throwingDataSource);
    useCase = UpdateZikZakScoreUseCase(repository);
    throwingUseCase = UpdateZikZakScoreUseCase(throwingRepository);
  });
  group('UpdateZikZakScoreUseCase', () {
    final tZikZakScore = ZikZakScoreMockData.sampleZikZakScore;
    test('should call repository.update and return result', () async {
      final result = await useCase.call(
        UpdateParams<String, ZikZakScorePatch>(
          id: tZikZakScore.id,
          data: ZikZakScorePatch(),
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        UpdateParams<String, ZikZakScorePatch>(
          id: tZikZakScore.id,
          data: ZikZakScorePatch(),
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
