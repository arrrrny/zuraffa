// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/nearby_grocery_store/nearby_grocery_store.dart';
import 'nearby_grocery_store_datasource.dart';

class NearbyGroceryStoreRemoteDataSource
    with Loggable, FailureHandler
    implements NearbyGroceryStoreDataSource {
  @override
  Future<NearbyGroceryStore> get(QueryParams<NearbyGroceryStore> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<NearbyGroceryStore> update(
    UpdateParams<String, NearbyGroceryStorePatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<NearbyGroceryStore> toggle(
    ToggleParams<String, Field<NearbyGroceryStore, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
