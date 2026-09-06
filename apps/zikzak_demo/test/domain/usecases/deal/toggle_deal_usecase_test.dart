// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/deal/deal_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/deal/deal_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/deal_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_deal_repository.dart';
import 'package:zikzak_demo/src/domain/entities/deal/deal.dart';
import 'package:zikzak_demo/src/domain/repositories/deal_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/deal/toggle_deal_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingDealDataSource
    with Loggable, FailureHandler
    implements DealDataSource {
  @override
  Future<Deal> get(QueryParams<Deal> params) {
    throw (Exception('ThrowingDealDataSource.get'));
  }

  @override
  Future<List<Deal>> getList(ListQueryParams<Deal> params) {
    throw (Exception('ThrowingDealDataSource.getList'));
  }

  @override
  Future<Deal> create(Deal entity) {
    throw (Exception('ThrowingDealDataSource.create'));
  }

  @override
  Future<Deal> update(UpdateParams<String, DealPatch> params) {
    throw (Exception('ThrowingDealDataSource.update'));
  }

  @override
  Future<Deal> toggle(ToggleParams<String, Field<Deal, dynamic>> params) {
    throw (Exception('ThrowingDealDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingDealDataSource.delete'));
  }

  @override
  Stream<Deal> watch(QueryParams<Deal> params) {
    throw (Exception('ThrowingDealDataSource.watch'));
  }

  @override
  Stream<List<Deal>> watchList(ListQueryParams<Deal> params) {
    throw (Exception('ThrowingDealDataSource.watchList'));
  }
}

void main() {
  late ToggleDealUseCase useCase;
  late ToggleDealUseCase throwingUseCase;
  late DataDealRepository repository;
  late DataDealRepository throwingRepository;
  late DealMockDataSource mockDataSource;
  late ThrowingDealDataSource throwingDataSource;
  setUp(() {
    mockDataSource = DealMockDataSource();
    throwingDataSource = ThrowingDealDataSource();
    repository = DataDealRepository(mockDataSource);
    throwingRepository = DataDealRepository(throwingDataSource);
    useCase = ToggleDealUseCase(repository);
    throwingUseCase = ToggleDealUseCase(throwingRepository);
  });
  group('ToggleDealUseCase', () {
    final tDeal = DealMockData.sampleDeal;
    test('should call repository.toggle and return result', () async {
      final result = await useCase.call(
        ToggleParams<String, Field<Deal, dynamic>>(
          id: tDeal.id,
          field: DealFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        ToggleParams<String, Field<Deal, dynamic>>(
          id: tDeal.id,
          field: DealFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
