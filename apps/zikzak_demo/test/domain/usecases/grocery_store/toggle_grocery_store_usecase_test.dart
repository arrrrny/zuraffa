// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/grocery_store/grocery_store_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/grocery_store/grocery_store_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/grocery_store_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_grocery_store_repository.dart';
import 'package:zikzak_demo/src/domain/entities/grocery_store/grocery_store.dart';
import 'package:zikzak_demo/src/domain/repositories/grocery_store_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/grocery_store/toggle_grocery_store_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingGroceryStoreDataSource
    with Loggable, FailureHandler
    implements GroceryStoreDataSource {
  @override
  Future<GroceryStore> get(QueryParams<GroceryStore> params) {
    throw (Exception('ThrowingGroceryStoreDataSource.get'));
  }

  @override
  Future<List<GroceryStore>> getList(ListQueryParams<GroceryStore> params) {
    throw (Exception('ThrowingGroceryStoreDataSource.getList'));
  }

  @override
  Future<GroceryStore> create(GroceryStore entity) {
    throw (Exception('ThrowingGroceryStoreDataSource.create'));
  }

  @override
  Future<GroceryStore> update(UpdateParams<String, GroceryStorePatch> params) {
    throw (Exception('ThrowingGroceryStoreDataSource.update'));
  }

  @override
  Future<GroceryStore> toggle(
    ToggleParams<String, Field<GroceryStore, dynamic>> params,
  ) {
    throw (Exception('ThrowingGroceryStoreDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingGroceryStoreDataSource.delete'));
  }

  @override
  Stream<GroceryStore> watch(QueryParams<GroceryStore> params) {
    throw (Exception('ThrowingGroceryStoreDataSource.watch'));
  }

  @override
  Stream<List<GroceryStore>> watchList(ListQueryParams<GroceryStore> params) {
    throw (Exception('ThrowingGroceryStoreDataSource.watchList'));
  }
}

void main() {
  late ToggleGroceryStoreUseCase useCase;
  late ToggleGroceryStoreUseCase throwingUseCase;
  late DataGroceryStoreRepository repository;
  late DataGroceryStoreRepository throwingRepository;
  late GroceryStoreMockDataSource mockDataSource;
  late ThrowingGroceryStoreDataSource throwingDataSource;
  setUp(() {
    mockDataSource = GroceryStoreMockDataSource();
    throwingDataSource = ThrowingGroceryStoreDataSource();
    repository = DataGroceryStoreRepository(mockDataSource);
    throwingRepository = DataGroceryStoreRepository(throwingDataSource);
    useCase = ToggleGroceryStoreUseCase(repository);
    throwingUseCase = ToggleGroceryStoreUseCase(throwingRepository);
  });
  group('ToggleGroceryStoreUseCase', () {
    final tGroceryStore = GroceryStoreMockData.sampleGroceryStore;
    test('should call repository.toggle and return result', () async {
      final result = await useCase.call(
        ToggleParams<String, Field<GroceryStore, dynamic>>(
          id: tGroceryStore.id,
          field: GroceryStoreFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        ToggleParams<String, Field<GroceryStore, dynamic>>(
          id: tGroceryStore.id,
          field: GroceryStoreFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
