// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/grocery_price_result/grocery_price_result.dart';
import 'grocery_price_result_datasource.dart';

class GroceryPriceResultRemoteDataSource
    with Loggable, FailureHandler
    implements GroceryPriceResultDataSource {
  @override
  Future<GroceryPriceResult> get(QueryParams<GroceryPriceResult> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<GroceryPriceResult> update(
    UpdateParams<String, GroceryPriceResultPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<GroceryPriceResult> toggle(
    ToggleParams<String, Field<GroceryPriceResult, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
