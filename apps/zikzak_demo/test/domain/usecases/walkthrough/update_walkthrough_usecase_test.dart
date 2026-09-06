// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/walkthrough/walkthrough_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/walkthrough/walkthrough_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/walkthrough_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_walkthrough_repository.dart';
import 'package:zikzak_demo/src/domain/entities/walkthrough/walkthrough.dart';
import 'package:zikzak_demo/src/domain/repositories/walkthrough_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/walkthrough/update_walkthrough_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingWalkthroughDataSource
    with Loggable, FailureHandler
    implements WalkthroughDataSource {
  @override
  Future<Walkthrough> get(QueryParams<Walkthrough> params) {
    throw (Exception('ThrowingWalkthroughDataSource.get'));
  }

  @override
  Future<List<Walkthrough>> getList(ListQueryParams<Walkthrough> params) {
    throw (Exception('ThrowingWalkthroughDataSource.getList'));
  }

  @override
  Future<Walkthrough> create(Walkthrough entity) {
    throw (Exception('ThrowingWalkthroughDataSource.create'));
  }

  @override
  Future<Walkthrough> update(UpdateParams<String, WalkthroughPatch> params) {
    throw (Exception('ThrowingWalkthroughDataSource.update'));
  }

  @override
  Future<Walkthrough> toggle(
    ToggleParams<String, Field<Walkthrough, dynamic>> params,
  ) {
    throw (Exception('ThrowingWalkthroughDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingWalkthroughDataSource.delete'));
  }

  @override
  Stream<Walkthrough> watch(QueryParams<Walkthrough> params) {
    throw (Exception('ThrowingWalkthroughDataSource.watch'));
  }

  @override
  Stream<List<Walkthrough>> watchList(ListQueryParams<Walkthrough> params) {
    throw (Exception('ThrowingWalkthroughDataSource.watchList'));
  }
}

void main() {
  late UpdateWalkthroughUseCase useCase;
  late UpdateWalkthroughUseCase throwingUseCase;
  late DataWalkthroughRepository repository;
  late DataWalkthroughRepository throwingRepository;
  late WalkthroughMockDataSource mockDataSource;
  late ThrowingWalkthroughDataSource throwingDataSource;
  setUp(() {
    mockDataSource = WalkthroughMockDataSource();
    throwingDataSource = ThrowingWalkthroughDataSource();
    repository = DataWalkthroughRepository(mockDataSource);
    throwingRepository = DataWalkthroughRepository(throwingDataSource);
    useCase = UpdateWalkthroughUseCase(repository);
    throwingUseCase = UpdateWalkthroughUseCase(throwingRepository);
  });
  group('UpdateWalkthroughUseCase', () {
    final tWalkthrough = WalkthroughMockData.sampleWalkthrough;
    test('should call repository.update and return result', () async {
      final result = await useCase.call(
        UpdateParams<String, WalkthroughPatch>(
          id: tWalkthrough.id,
          data: WalkthroughPatch(),
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        UpdateParams<String, WalkthroughPatch>(
          id: tWalkthrough.id,
          data: WalkthroughPatch(),
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
