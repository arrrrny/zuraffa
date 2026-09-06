// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/grocery_item/grocery_item_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/grocery_item/grocery_item_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/grocery_item_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_grocery_item_repository.dart';
import 'package:zikzak_demo/src/domain/entities/grocery_item/grocery_item.dart';
import 'package:zikzak_demo/src/domain/repositories/grocery_item_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/grocery_item/toggle_grocery_item_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingGroceryItemDataSource
    with Loggable, FailureHandler
    implements GroceryItemDataSource {
  @override
  Future<GroceryItem> get(QueryParams<GroceryItem> params) {
    throw (Exception('ThrowingGroceryItemDataSource.get'));
  }

  @override
  Future<List<GroceryItem>> getList(ListQueryParams<GroceryItem> params) {
    throw (Exception('ThrowingGroceryItemDataSource.getList'));
  }

  @override
  Future<GroceryItem> create(GroceryItem entity) {
    throw (Exception('ThrowingGroceryItemDataSource.create'));
  }

  @override
  Future<GroceryItem> update(UpdateParams<String, GroceryItemPatch> params) {
    throw (Exception('ThrowingGroceryItemDataSource.update'));
  }

  @override
  Future<GroceryItem> toggle(
    ToggleParams<String, Field<GroceryItem, dynamic>> params,
  ) {
    throw (Exception('ThrowingGroceryItemDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingGroceryItemDataSource.delete'));
  }

  @override
  Stream<GroceryItem> watch(QueryParams<GroceryItem> params) {
    throw (Exception('ThrowingGroceryItemDataSource.watch'));
  }

  @override
  Stream<List<GroceryItem>> watchList(ListQueryParams<GroceryItem> params) {
    throw (Exception('ThrowingGroceryItemDataSource.watchList'));
  }
}

void main() {
  late ToggleGroceryItemUseCase useCase;
  late ToggleGroceryItemUseCase throwingUseCase;
  late DataGroceryItemRepository repository;
  late DataGroceryItemRepository throwingRepository;
  late GroceryItemMockDataSource mockDataSource;
  late ThrowingGroceryItemDataSource throwingDataSource;
  setUp(() {
    mockDataSource = GroceryItemMockDataSource();
    throwingDataSource = ThrowingGroceryItemDataSource();
    repository = DataGroceryItemRepository(mockDataSource);
    throwingRepository = DataGroceryItemRepository(throwingDataSource);
    useCase = ToggleGroceryItemUseCase(repository);
    throwingUseCase = ToggleGroceryItemUseCase(throwingRepository);
  });
  group('ToggleGroceryItemUseCase', () {
    final tGroceryItem = GroceryItemMockData.sampleGroceryItem;
    test('should call repository.toggle and return result', () async {
      final result = await useCase.call(
        ToggleParams<String, Field<GroceryItem, dynamic>>(
          id: tGroceryItem.id,
          field: GroceryItemFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        ToggleParams<String, Field<GroceryItem, dynamic>>(
          id: tGroceryItem.id,
          field: GroceryItemFields.id,
          value: 'toggled',
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
