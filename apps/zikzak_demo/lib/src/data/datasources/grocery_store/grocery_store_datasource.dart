// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/grocery_store/grocery_store.dart';

abstract class GroceryStoreDataSource with Loggable, FailureHandler {
  Future<GroceryStore> get(QueryParams<GroceryStore> params);
  Future<GroceryStore> update(UpdateParams<String, GroceryStorePatch> params);
  Future<GroceryStore> toggle(
    ToggleParams<String, Field<GroceryStore, dynamic>> params,
  );
}

// END GENERATED
