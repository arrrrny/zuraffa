// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/walkthrough_view/walkthrough_view_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/walkthrough_view/walkthrough_view_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/walkthrough_view_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_walkthrough_view_repository.dart';
import 'package:zikzak_demo/src/domain/entities/walkthrough_view/walkthrough_view.dart';
import 'package:zikzak_demo/src/domain/repositories/walkthrough_view_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/walkthrough_view/toggle_walkthrough_view_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingWalkthroughViewDataSource
    with Loggable, FailureHandler
    implements WalkthroughViewDataSource {
  @override
  Future<WalkthroughView> get(QueryParams<WalkthroughView> params) {
    throw (Exception('ThrowingWalkthroughViewDataSource.get'));
  }

  @override
  Future<List<WalkthroughView>> getList(
    ListQueryParams<WalkthroughView> params,
  ) {
    throw (Exception('ThrowingWalkthroughViewDataSource.getList'));
  }

  @override
  Future<WalkthroughView> create(WalkthroughView entity) {
    throw (Exception('ThrowingWalkthroughViewDataSource.create'));
  }

  @override
  Future<WalkthroughView> update(
    UpdateParams<String, WalkthroughViewPatch> params,
  ) {
    throw (Exception('ThrowingWalkthroughViewDataSource.update'));
  }

  @override
  Future<WalkthroughView> toggle(
    ToggleParams<String, Field<WalkthroughView, dynamic>> params,
  ) {
    throw (Exception('ThrowingWalkthroughViewDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingWalkthroughViewDataSource.delete'));
  }

  @override
  Stream<WalkthroughView> watch(QueryParams<WalkthroughView> params) {
    throw (Exception('ThrowingWalkthroughViewDataSource.watch'));
  }

  @override
  Stream<List<WalkthroughView>> watchList(
    ListQueryParams<WalkthroughView> params,
  ) {
    throw (Exception('ThrowingWalkthroughViewDataSource.watchList'));
  }
}

void main() {
  late ToggleWalkthroughViewUseCase useCase;
  late ToggleWalkthroughViewUseCase throwingUseCase;
  late DataWalkthroughViewRepository repository;
  late DataWalkthroughViewRepository throwingRepository;
  late WalkthroughViewMockDataSource mockDataSource;
  late ThrowingWalkthroughViewDataSource throwingDataSource;
  setUp(() {
    mockDataSource = WalkthroughViewMockDataSource();
    throwingDataSource = ThrowingWalkthroughViewDataSource();
    repository = DataWalkthroughViewRepository(mockDataSource);
    throwingRepository = DataWalkthroughViewRepository(throwingDataSource);
    useCase = ToggleWalkthroughViewUseCase(repository);
    throwingUseCase = ToggleWalkthroughViewUseCase(throwingRepository);
  });
  group('ToggleWalkthroughViewUseCase', () {
    final tWalkthroughView = WalkthroughViewMockData.sampleWalkthroughView;
    test('should call repository.toggle and return result', () async {
      final result = await useCase.call(
        ToggleParams<String, Field<WalkthroughView, dynamic>>(
          id: tWalkthroughView.id,
          field: WalkthroughViewFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        ToggleParams<String, Field<WalkthroughView, dynamic>>(
          id: tWalkthroughView.id,
          field: WalkthroughViewFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
