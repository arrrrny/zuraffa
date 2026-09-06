// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/grocery_product/grocery_product.dart';

abstract class GroceryProductDataSource with Loggable, FailureHandler {
  Future<GroceryProduct> get(QueryParams<GroceryProduct> params);
  Future<GroceryProduct> update(
    UpdateParams<String, GroceryProductPatch> params,
  );
  Future<GroceryProduct> toggle(
    ToggleParams<String, Field<GroceryProduct, dynamic>> params,
  );
}

// END GENERATED
