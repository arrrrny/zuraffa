// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/grocery_price_comparison/grocery_price_comparison_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/grocery_price_comparison/grocery_price_comparison_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/grocery_price_comparison_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_grocery_price_comparison_repository.dart';
import 'package:zikzak_demo/src/domain/entities/grocery_price_comparison/grocery_price_comparison.dart';
import 'package:zikzak_demo/src/domain/repositories/grocery_price_comparison_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/grocery_price_comparison/get_grocery_price_comparison_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingGroceryPriceComparisonDataSource
    with Loggable, FailureHandler
    implements GroceryPriceComparisonDataSource {
  @override
  Future<GroceryPriceComparison> get(
    QueryParams<GroceryPriceComparison> params,
  ) {
    throw (Exception('ThrowingGroceryPriceComparisonDataSource.get'));
  }

  @override
  Future<List<GroceryPriceComparison>> getList(
    ListQueryParams<GroceryPriceComparison> params,
  ) {
    throw (Exception('ThrowingGroceryPriceComparisonDataSource.getList'));
  }

  @override
  Future<GroceryPriceComparison> create(GroceryPriceComparison entity) {
    throw (Exception('ThrowingGroceryPriceComparisonDataSource.create'));
  }

  @override
  Future<GroceryPriceComparison> update(
    UpdateParams<String, GroceryPriceComparisonPatch> params,
  ) {
    throw (Exception('ThrowingGroceryPriceComparisonDataSource.update'));
  }

  @override
  Future<GroceryPriceComparison> toggle(
    ToggleParams<String, Field<GroceryPriceComparison, dynamic>> params,
  ) {
    throw (Exception('ThrowingGroceryPriceComparisonDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingGroceryPriceComparisonDataSource.delete'));
  }

  @override
  Stream<GroceryPriceComparison> watch(
    QueryParams<GroceryPriceComparison> params,
  ) {
    throw (Exception('ThrowingGroceryPriceComparisonDataSource.watch'));
  }

  @override
  Stream<List<GroceryPriceComparison>> watchList(
    ListQueryParams<GroceryPriceComparison> params,
  ) {
    throw (Exception('ThrowingGroceryPriceComparisonDataSource.watchList'));
  }
}

void main() {
  late GetGroceryPriceComparisonUseCase useCase;
  late GetGroceryPriceComparisonUseCase throwingUseCase;
  late DataGroceryPriceComparisonRepository repository;
  late DataGroceryPriceComparisonRepository throwingRepository;
  late GroceryPriceComparisonMockDataSource mockDataSource;
  late ThrowingGroceryPriceComparisonDataSource throwingDataSource;
  setUp(() {
    mockDataSource = GroceryPriceComparisonMockDataSource();
    throwingDataSource = ThrowingGroceryPriceComparisonDataSource();
    repository = DataGroceryPriceComparisonRepository(mockDataSource);
    throwingRepository = DataGroceryPriceComparisonRepository(
      throwingDataSource,
    );
    useCase = GetGroceryPriceComparisonUseCase(repository);
    throwingUseCase = GetGroceryPriceComparisonUseCase(throwingRepository);
  });
  group('GetGroceryPriceComparisonUseCase', () {
    final tGroceryPriceComparison =
        GroceryPriceComparisonMockData.sampleGroceryPriceComparison;
    test('should call repository.get and return result', () async {
      final result = await useCase.call(
        QueryParams<GroceryPriceComparison>(
          filter: Eq(
            GroceryPriceComparisonFields.itemId,
            tGroceryPriceComparison.itemId,
          ),
        ),
      );
      expect(result.isSuccess, true);
      expect(
        result.getOrElse(() => throw (Exception('not success'))),
        equals(tGroceryPriceComparison),
      );
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        QueryParams<GroceryPriceComparison>(
          filter: Eq(
            GroceryPriceComparisonFields.itemId,
            tGroceryPriceComparison.itemId,
          ),
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
