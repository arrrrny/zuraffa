// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/grocery_store/grocery_store.dart';
import 'grocery_store_datasource.dart';

class GroceryStoreRemoteDataSource
    with Loggable, FailureHandler
    implements GroceryStoreDataSource {
  @override
  Future<GroceryStore> get(QueryParams<GroceryStore> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<GroceryStore> update(
    UpdateParams<String, GroceryStorePatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<GroceryStore> toggle(
    ToggleParams<String, Field<GroceryStore, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
