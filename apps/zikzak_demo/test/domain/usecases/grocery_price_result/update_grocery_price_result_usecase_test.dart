// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/grocery_price_result/grocery_price_result_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/grocery_price_result/grocery_price_result_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/grocery_price_result_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_grocery_price_result_repository.dart';
import 'package:zikzak_demo/src/domain/entities/grocery_price_result/grocery_price_result.dart';
import 'package:zikzak_demo/src/domain/repositories/grocery_price_result_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/grocery_price_result/update_grocery_price_result_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingGroceryPriceResultDataSource
    with Loggable, FailureHandler
    implements GroceryPriceResultDataSource {
  @override
  Future<GroceryPriceResult> get(QueryParams<GroceryPriceResult> params) {
    throw (Exception('ThrowingGroceryPriceResultDataSource.get'));
  }

  @override
  Future<List<GroceryPriceResult>> getList(
    ListQueryParams<GroceryPriceResult> params,
  ) {
    throw (Exception('ThrowingGroceryPriceResultDataSource.getList'));
  }

  @override
  Future<GroceryPriceResult> create(GroceryPriceResult entity) {
    throw (Exception('ThrowingGroceryPriceResultDataSource.create'));
  }

  @override
  Future<GroceryPriceResult> update(
    UpdateParams<String, GroceryPriceResultPatch> params,
  ) {
    throw (Exception('ThrowingGroceryPriceResultDataSource.update'));
  }

  @override
  Future<GroceryPriceResult> toggle(
    ToggleParams<String, Field<GroceryPriceResult, dynamic>> params,
  ) {
    throw (Exception('ThrowingGroceryPriceResultDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingGroceryPriceResultDataSource.delete'));
  }

  @override
  Stream<GroceryPriceResult> watch(QueryParams<GroceryPriceResult> params) {
    throw (Exception('ThrowingGroceryPriceResultDataSource.watch'));
  }

  @override
  Stream<List<GroceryPriceResult>> watchList(
    ListQueryParams<GroceryPriceResult> params,
  ) {
    throw (Exception('ThrowingGroceryPriceResultDataSource.watchList'));
  }
}

void main() {
  late UpdateGroceryPriceResultUseCase useCase;
  late UpdateGroceryPriceResultUseCase throwingUseCase;
  late DataGroceryPriceResultRepository repository;
  late DataGroceryPriceResultRepository throwingRepository;
  late GroceryPriceResultMockDataSource mockDataSource;
  late ThrowingGroceryPriceResultDataSource throwingDataSource;
  setUp(() {
    mockDataSource = GroceryPriceResultMockDataSource();
    throwingDataSource = ThrowingGroceryPriceResultDataSource();
    repository = DataGroceryPriceResultRepository(mockDataSource);
    throwingRepository = DataGroceryPriceResultRepository(throwingDataSource);
    useCase = UpdateGroceryPriceResultUseCase(repository);
    throwingUseCase = UpdateGroceryPriceResultUseCase(throwingRepository);
  });
  group('UpdateGroceryPriceResultUseCase', () {
    final tGroceryPriceResult =
        GroceryPriceResultMockData.sampleGroceryPriceResult;
    test('should call repository.update and return result', () async {
      final result = await useCase.call(
        UpdateParams<String, GroceryPriceResultPatch>(
          id: tGroceryPriceResult.storeName,
          data: GroceryPriceResultPatch(),
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        UpdateParams<String, GroceryPriceResultPatch>(
          id: tGroceryPriceResult.storeName,
          data: GroceryPriceResultPatch(),
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
