// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/walkthrough_step/walkthrough_step_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/walkthrough_step/walkthrough_step_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/walkthrough_step_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_walkthrough_step_repository.dart';
import 'package:zikzak_demo/src/domain/entities/walkthrough_step/walkthrough_step.dart';
import 'package:zikzak_demo/src/domain/repositories/walkthrough_step_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/walkthrough_step/get_walkthrough_step_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingWalkthroughStepDataSource
    with Loggable, FailureHandler
    implements WalkthroughStepDataSource {
  @override
  Future<WalkthroughStep> get(QueryParams<WalkthroughStep> params) {
    throw (Exception('ThrowingWalkthroughStepDataSource.get'));
  }

  @override
  Future<List<WalkthroughStep>> getList(
    ListQueryParams<WalkthroughStep> params,
  ) {
    throw (Exception('ThrowingWalkthroughStepDataSource.getList'));
  }

  @override
  Future<WalkthroughStep> create(WalkthroughStep entity) {
    throw (Exception('ThrowingWalkthroughStepDataSource.create'));
  }

  @override
  Future<WalkthroughStep> update(
    UpdateParams<String, WalkthroughStepPatch> params,
  ) {
    throw (Exception('ThrowingWalkthroughStepDataSource.update'));
  }

  @override
  Future<WalkthroughStep> toggle(
    ToggleParams<String, Field<WalkthroughStep, dynamic>> params,
  ) {
    throw (Exception('ThrowingWalkthroughStepDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingWalkthroughStepDataSource.delete'));
  }

  @override
  Stream<WalkthroughStep> watch(QueryParams<WalkthroughStep> params) {
    throw (Exception('ThrowingWalkthroughStepDataSource.watch'));
  }

  @override
  Stream<List<WalkthroughStep>> watchList(
    ListQueryParams<WalkthroughStep> params,
  ) {
    throw (Exception('ThrowingWalkthroughStepDataSource.watchList'));
  }
}

void main() {
  late GetWalkthroughStepUseCase useCase;
  late GetWalkthroughStepUseCase throwingUseCase;
  late DataWalkthroughStepRepository repository;
  late DataWalkthroughStepRepository throwingRepository;
  late WalkthroughStepMockDataSource mockDataSource;
  late ThrowingWalkthroughStepDataSource throwingDataSource;
  setUp(() {
    mockDataSource = WalkthroughStepMockDataSource();
    throwingDataSource = ThrowingWalkthroughStepDataSource();
    repository = DataWalkthroughStepRepository(mockDataSource);
    throwingRepository = DataWalkthroughStepRepository(throwingDataSource);
    useCase = GetWalkthroughStepUseCase(repository);
    throwingUseCase = GetWalkthroughStepUseCase(throwingRepository);
  });
  group('GetWalkthroughStepUseCase', () {
    final tWalkthroughStep = WalkthroughStepMockData.sampleWalkthroughStep;
    test('should call repository.get and return result', () async {
      final result = await useCase.call(
        QueryParams<WalkthroughStep>(
          filter: Eq(WalkthroughStepFields.id, tWalkthroughStep.id),
        ),
      );
      expect(result.isSuccess, true);
      expect(
        result.getOrElse(() => throw (Exception('not success'))),
        equals(tWalkthroughStep),
      );
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        QueryParams<WalkthroughStep>(
          filter: Eq(WalkthroughStepFields.id, tWalkthroughStep.id),
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
