// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/grocery_price_comparison/grocery_price_comparison.dart';

abstract class GroceryPriceComparisonDataSource with Loggable, FailureHandler {
  Future<GroceryPriceComparison> get(
    QueryParams<GroceryPriceComparison> params,
  );
  Future<GroceryPriceComparison> update(
    UpdateParams<String, GroceryPriceComparisonPatch> params,
  );
  Future<GroceryPriceComparison> toggle(
    ToggleParams<String, Field<GroceryPriceComparison, dynamic>> params,
  );
}

// END GENERATED
