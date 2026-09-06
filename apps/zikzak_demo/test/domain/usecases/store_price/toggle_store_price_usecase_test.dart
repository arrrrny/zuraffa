// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/store_price/store_price_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/store_price/store_price_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/store_price_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_store_price_repository.dart';
import 'package:zikzak_demo/src/domain/entities/store_price/store_price.dart';
import 'package:zikzak_demo/src/domain/repositories/store_price_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/store_price/toggle_store_price_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingStorePriceDataSource
    with Loggable, FailureHandler
    implements StorePriceDataSource {
  @override
  Future<StorePrice> get(QueryParams<StorePrice> params) {
    throw (Exception('ThrowingStorePriceDataSource.get'));
  }

  @override
  Future<List<StorePrice>> getList(ListQueryParams<StorePrice> params) {
    throw (Exception('ThrowingStorePriceDataSource.getList'));
  }

  @override
  Future<StorePrice> create(StorePrice entity) {
    throw (Exception('ThrowingStorePriceDataSource.create'));
  }

  @override
  Future<StorePrice> update(UpdateParams<String, StorePricePatch> params) {
    throw (Exception('ThrowingStorePriceDataSource.update'));
  }

  @override
  Future<StorePrice> toggle(
    ToggleParams<String, Field<StorePrice, dynamic>> params,
  ) {
    throw (Exception('ThrowingStorePriceDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingStorePriceDataSource.delete'));
  }

  @override
  Stream<StorePrice> watch(QueryParams<StorePrice> params) {
    throw (Exception('ThrowingStorePriceDataSource.watch'));
  }

  @override
  Stream<List<StorePrice>> watchList(ListQueryParams<StorePrice> params) {
    throw (Exception('ThrowingStorePriceDataSource.watchList'));
  }
}

void main() {
  late ToggleStorePriceUseCase useCase;
  late ToggleStorePriceUseCase throwingUseCase;
  late DataStorePriceRepository repository;
  late DataStorePriceRepository throwingRepository;
  late StorePriceMockDataSource mockDataSource;
  late ThrowingStorePriceDataSource throwingDataSource;
  setUp(() {
    mockDataSource = StorePriceMockDataSource();
    throwingDataSource = ThrowingStorePriceDataSource();
    repository = DataStorePriceRepository(mockDataSource);
    throwingRepository = DataStorePriceRepository(throwingDataSource);
    useCase = ToggleStorePriceUseCase(repository);
    throwingUseCase = ToggleStorePriceUseCase(throwingRepository);
  });
  group('ToggleStorePriceUseCase', () {
    final tStorePrice = StorePriceMockData.sampleStorePrice;
    test('should call repository.toggle and return result', () async {
      final result = await useCase.call(
        ToggleParams<String, Field<StorePrice, dynamic>>(
          id: tStorePrice.depotId,
          field: StorePriceFields.depotId,
          value: 'toggled',
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        ToggleParams<String, Field<StorePrice, dynamic>>(
          id: tStorePrice.depotId,
          field: StorePriceFields.depotId,
          value: 'toggled',
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
