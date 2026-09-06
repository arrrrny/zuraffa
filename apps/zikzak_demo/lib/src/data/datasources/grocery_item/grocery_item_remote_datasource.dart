// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/grocery_item/grocery_item.dart';
import 'grocery_item_datasource.dart';

class GroceryItemRemoteDataSource
    with Loggable, FailureHandler
    implements GroceryItemDataSource {
  @override
  Future<GroceryItem> get(QueryParams<GroceryItem> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<GroceryItem> update(
    UpdateParams<String, GroceryItemPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<GroceryItem> toggle(
    ToggleParams<String, Field<GroceryItem, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
