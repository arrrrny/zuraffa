// GENERATED - DO NOT EDIT
import 'package:flutter_test/flutter_test.dart';
import 'package:zikzak_demo/src/data/datasources/nearby_grocery_store/nearby_grocery_store_datasource.dart';
import 'package:zikzak_demo/src/data/datasources/nearby_grocery_store/nearby_grocery_store_mock_datasource.dart';
import 'package:zikzak_demo/src/data/mock/nearby_grocery_store_mock_data.dart';
import 'package:zikzak_demo/src/data/repositories/data_nearby_grocery_store_repository.dart';
import 'package:zikzak_demo/src/domain/entities/nearby_grocery_store/nearby_grocery_store.dart';
import 'package:zikzak_demo/src/domain/repositories/nearby_grocery_store_repository.dart';
import 'package:zikzak_demo/src/domain/usecases/nearby_grocery_store/get_nearby_grocery_store_usecase.dart';
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

class ThrowingNearbyGroceryStoreDataSource
    with Loggable, FailureHandler
    implements NearbyGroceryStoreDataSource {
  @override
  Future<NearbyGroceryStore> get(QueryParams<NearbyGroceryStore> params) {
    throw (Exception('ThrowingNearbyGroceryStoreDataSource.get'));
  }

  @override
  Future<List<NearbyGroceryStore>> getList(
    ListQueryParams<NearbyGroceryStore> params,
  ) {
    throw (Exception('ThrowingNearbyGroceryStoreDataSource.getList'));
  }

  @override
  Future<NearbyGroceryStore> create(NearbyGroceryStore entity) {
    throw (Exception('ThrowingNearbyGroceryStoreDataSource.create'));
  }

  @override
  Future<NearbyGroceryStore> update(
    UpdateParams<String, NearbyGroceryStorePatch> params,
  ) {
    throw (Exception('ThrowingNearbyGroceryStoreDataSource.update'));
  }

  @override
  Future<NearbyGroceryStore> toggle(
    ToggleParams<String, Field<NearbyGroceryStore, dynamic>> params,
  ) {
    throw (Exception('ThrowingNearbyGroceryStoreDataSource.toggle'));
  }

  @override
  Future<Map<String, dynamic>> delete(DeleteParams<String> params) {
    throw (Exception('ThrowingNearbyGroceryStoreDataSource.delete'));
  }

  @override
  Stream<NearbyGroceryStore> watch(QueryParams<NearbyGroceryStore> params) {
    throw (Exception('ThrowingNearbyGroceryStoreDataSource.watch'));
  }

  @override
  Stream<List<NearbyGroceryStore>> watchList(
    ListQueryParams<NearbyGroceryStore> params,
  ) {
    throw (Exception('ThrowingNearbyGroceryStoreDataSource.watchList'));
  }
}

void main() {
  late GetNearbyGroceryStoreUseCase useCase;
  late GetNearbyGroceryStoreUseCase throwingUseCase;
  late DataNearbyGroceryStoreRepository repository;
  late DataNearbyGroceryStoreRepository throwingRepository;
  late NearbyGroceryStoreMockDataSource mockDataSource;
  late ThrowingNearbyGroceryStoreDataSource throwingDataSource;
  setUp(() {
    mockDataSource = NearbyGroceryStoreMockDataSource();
    throwingDataSource = ThrowingNearbyGroceryStoreDataSource();
    repository = DataNearbyGroceryStoreRepository(mockDataSource);
    throwingRepository = DataNearbyGroceryStoreRepository(throwingDataSource);
    useCase = GetNearbyGroceryStoreUseCase(repository);
    throwingUseCase = GetNearbyGroceryStoreUseCase(throwingRepository);
  });
  group('GetNearbyGroceryStoreUseCase', () {
    final tNearbyGroceryStore =
        NearbyGroceryStoreMockData.sampleNearbyGroceryStore;
    test('should call repository.get and return result', () async {
      final result = await useCase.call(
        QueryParams<NearbyGroceryStore>(
          filter: Eq(NearbyGroceryStoreFields.id, tNearbyGroceryStore.id),
        ),
      );
      expect(result.isSuccess, true);
      expect(
        result.getOrElse(() => throw (Exception('not success'))),
        equals(tNearbyGroceryStore),
      );
    });
    test('should return Failure when repository throws', () async {
      final result = await throwingUseCase.call(
        QueryParams<NearbyGroceryStore>(
          filter: Eq(NearbyGroceryStoreFields.id, tNearbyGroceryStore.id),
        ),
      );
      expect(result.isFailure, true);
    });
  });
}

// END GENERATED
