// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/grocery_product/grocery_product_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/grocery_product/grocery_product_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/grocery_product_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_grocery_product_repository.dart';
import 'package:zikzak_demo/src/domain/entities/grocery_product/grocery_product.dart';
import 'package:zikzak_demo/src/domain/repositories/grocery_product_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/grocery_product/get_grocery_product_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingGroceryProductDataSource
    with Loggable, FailureHandler
    implements GroceryProductDataSource {
  @override
  Future<GroceryProduct> get(QueryParams<GroceryProduct> params) {
    throw (Exception('ThrowingGroceryProductDataSource.get'));
  }

  @override
  Future<List<GroceryProduct>> getList(ListQueryParams<GroceryProduct> params) {
    throw (Exception('ThrowingGroceryProductDataSource.getList'));
  }

  @override
  Future<GroceryProduct> create(GroceryProduct entity) {
    throw (Exception('ThrowingGroceryProductDataSource.create'));
  }

  @override
  Future<GroceryProduct> update(
    UpdateParams<String, GroceryProductPatch> params,
  ) {
    throw (Exception('ThrowingGroceryProductDataSource.update'));
  }

  @override
  Future<GroceryProduct> toggle(
    ToggleParams<String, Field<GroceryProduct, dynamic>> params,
  ) {
    throw (Exception('ThrowingGroceryProductDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingGroceryProductDataSource.delete'));
  }

  @override
  Stream<GroceryProduct> watch(QueryParams<GroceryProduct> params) {
    throw (Exception('ThrowingGroceryProductDataSource.watch'));
  }

  @override
  Stream<List<GroceryProduct>> watchList(
    ListQueryParams<GroceryProduct> params,
  ) {
    throw (Exception('ThrowingGroceryProductDataSource.watchList'));
  }
}

void main() {
  late GetGroceryProductUseCase useCase;
  late GetGroceryProductUseCase throwingUseCase;
  late DataGroceryProductRepository repository;
  late DataGroceryProductRepository throwingRepository;
  late GroceryProductMockDataSource mockDataSource;
  late ThrowingGroceryProductDataSource throwingDataSource;
  setUp(() {
    mockDataSource = GroceryProductMockDataSource();
    throwingDataSource = ThrowingGroceryProductDataSource();
    repository = DataGroceryProductRepository(mockDataSource);
    throwingRepository = DataGroceryProductRepository(throwingDataSource);
    useCase = GetGroceryProductUseCase(repository);
    throwingUseCase = GetGroceryProductUseCase(throwingRepository);
  });
  group('GetGroceryProductUseCase', () {
    final tGroceryProduct = GroceryProductMockData.sampleGroceryProduct;
    test('should call repository.get and return result', () async {
      final result = await useCase.call(
        QueryParams<GroceryProduct>(
          filter: Eq(GroceryProductFields.id, tGroceryProduct.id),
        ),
      );
      expect(result.isSuccess, true);
      expect(
        result.getOrElse(() => throw (Exception('not success'))),
        equals(tGroceryProduct),
      );
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        QueryParams<GroceryProduct>(
          filter: Eq(GroceryProductFields.id, tGroceryProduct.id),
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
