// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/grocery_item/grocery_item.dart';

abstract class GroceryItemDataSource with Loggable, FailureHandler {
  Future<GroceryItem> get(QueryParams<GroceryItem> params);
  Future<GroceryItem> update(UpdateParams<String, GroceryItemPatch> params);
  Future<GroceryItem> toggle(
    ToggleParams<String, Field<GroceryItem, dynamic>> params,
  );
}

// END GENERATED
