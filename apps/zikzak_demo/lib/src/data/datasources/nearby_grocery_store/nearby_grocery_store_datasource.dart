// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/nearby_grocery_store/nearby_grocery_store.dart';

abstract class NearbyGroceryStoreDataSource with Loggable, FailureHandler {
  Future<NearbyGroceryStore> get(QueryParams<NearbyGroceryStore> params);
  Future<NearbyGroceryStore> update(
    UpdateParams<String, NearbyGroceryStorePatch> params,
  );
  Future<NearbyGroceryStore> toggle(
    ToggleParams<String, Field<NearbyGroceryStore, dynamic>> params,
  );
}

// END GENERATED
