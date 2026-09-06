// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/grocery_price_result/grocery_price_result.dart';

abstract class GroceryPriceResultDataSource with Loggable, FailureHandler {
  Future<GroceryPriceResult> get(QueryParams<GroceryPriceResult> params);
  Future<GroceryPriceResult> update(
    UpdateParams<String, GroceryPriceResultPatch> params,
  );
  Future<GroceryPriceResult> toggle(
    ToggleParams<String, Field<GroceryPriceResult, dynamic>> params,
  );
}

// END GENERATED
