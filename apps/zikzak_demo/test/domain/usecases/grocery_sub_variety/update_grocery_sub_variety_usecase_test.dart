// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/grocery_sub_variety/grocery_sub_variety_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/grocery_sub_variety/grocery_sub_variety_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/grocery_sub_variety_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_grocery_sub_variety_repository.dart';
import 'package:zikzak_demo/src/domain/entities/grocery_sub_variety/grocery_sub_variety.dart';
import 'package:zikzak_demo/src/domain/repositories/grocery_sub_variety_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/grocery_sub_variety/update_grocery_sub_variety_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingGrocerySubVarietyDataSource
    with Loggable, FailureHandler
    implements GrocerySubVarietyDataSource {
  @override
  Future<GrocerySubVariety> get(QueryParams<GrocerySubVariety> params) {
    throw (Exception('ThrowingGrocerySubVarietyDataSource.get'));
  }

  @override
  Future<List<GrocerySubVariety>> getList(
    ListQueryParams<GrocerySubVariety> params,
  ) {
    throw (Exception('ThrowingGrocerySubVarietyDataSource.getList'));
  }

  @override
  Future<GrocerySubVariety> create(GrocerySubVariety entity) {
    throw (Exception('ThrowingGrocerySubVarietyDataSource.create'));
  }

  @override
  Future<GrocerySubVariety> update(
    UpdateParams<String, GrocerySubVarietyPatch> params,
  ) {
    throw (Exception('ThrowingGrocerySubVarietyDataSource.update'));
  }

  @override
  Future<GrocerySubVariety> toggle(
    ToggleParams<String, Field<GrocerySubVariety, dynamic>> params,
  ) {
    throw (Exception('ThrowingGrocerySubVarietyDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingGrocerySubVarietyDataSource.delete'));
  }

  @override
  Stream<GrocerySubVariety> watch(QueryParams<GrocerySubVariety> params) {
    throw (Exception('ThrowingGrocerySubVarietyDataSource.watch'));
  }

  @override
  Stream<List<GrocerySubVariety>> watchList(
    ListQueryParams<GrocerySubVariety> params,
  ) {
    throw (Exception('ThrowingGrocerySubVarietyDataSource.watchList'));
  }
}

void main() {
  late UpdateGrocerySubVarietyUseCase useCase;
  late UpdateGrocerySubVarietyUseCase throwingUseCase;
  late DataGrocerySubVarietyRepository repository;
  late DataGrocerySubVarietyRepository throwingRepository;
  late GrocerySubVarietyMockDataSource mockDataSource;
  late ThrowingGrocerySubVarietyDataSource throwingDataSource;
  setUp(() {
    mockDataSource = GrocerySubVarietyMockDataSource();
    throwingDataSource = ThrowingGrocerySubVarietyDataSource();
    repository = DataGrocerySubVarietyRepository(mockDataSource);
    throwingRepository = DataGrocerySubVarietyRepository(throwingDataSource);
    useCase = UpdateGrocerySubVarietyUseCase(repository);
    throwingUseCase = UpdateGrocerySubVarietyUseCase(throwingRepository);
  });
  group('UpdateGrocerySubVarietyUseCase', () {
    final tGrocerySubVariety =
        GrocerySubVarietyMockData.sampleGrocerySubVariety;
    test('should call repository.update and return result', () async {
      final result = await useCase.call(
        UpdateParams<String, GrocerySubVarietyPatch>(
          id: tGrocerySubVariety.id,
          data: GrocerySubVarietyPatch(),
        ),
      );
      expect(result.isSuccess, true);
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        UpdateParams<String, GrocerySubVarietyPatch>(
          id: tGrocerySubVariety.id,
          data: GrocerySubVarietyPatch(),
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
