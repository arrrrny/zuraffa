// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/grocery_price_comparison/grocery_price_comparison.dart';
import 'grocery_price_comparison_datasource.dart';

class GroceryPriceComparisonRemoteDataSource
    with Loggable, FailureHandler
    implements GroceryPriceComparisonDataSource {
  @override
  Future<GroceryPriceComparison> get(
    QueryParams<GroceryPriceComparison> params,
  ) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<GroceryPriceComparison> update(
    UpdateParams<String, GroceryPriceComparisonPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<GroceryPriceComparison> toggle(
    ToggleParams<String, Field<GroceryPriceComparison, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
