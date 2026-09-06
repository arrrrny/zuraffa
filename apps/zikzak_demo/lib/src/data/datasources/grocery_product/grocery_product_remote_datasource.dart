// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/grocery_product/grocery_product.dart';
import 'grocery_product_datasource.dart';

class GroceryProductRemoteDataSource
    with Loggable, FailureHandler
    implements GroceryProductDataSource {
  @override
  Future<GroceryProduct> get(QueryParams<GroceryProduct> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<GroceryProduct> update(
    UpdateParams<String, GroceryProductPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<GroceryProduct> toggle(
    ToggleParams<String, Field<GroceryProduct, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
