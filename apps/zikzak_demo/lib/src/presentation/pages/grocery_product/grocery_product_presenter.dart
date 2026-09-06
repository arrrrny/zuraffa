// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/grocery_product/grocery_product.dart';
import '../../../domain/usecases/grocery_product/get_grocery_product_usecase.dart';
import '../../../domain/usecases/grocery_product/toggle_grocery_product_usecase.dart';
import '../../../domain/usecases/grocery_product/update_grocery_product_usecase.dart';

class GroceryProductPresenter extends Presenter {
  GroceryProductPresenter() {
    _getGroceryProduct = registerUseCase(getIt<GetGroceryProductUseCase>());
    _updateGroceryProduct = registerUseCase(
      getIt<UpdateGroceryProductUseCase>(),
    );
    _toggleGroceryProduct = registerUseCase(
      getIt<ToggleGroceryProductUseCase>(),
    );
  }

  late final GetGroceryProductUseCase _getGroceryProduct;

  late final UpdateGroceryProductUseCase _updateGroceryProduct;

  late final ToggleGroceryProductUseCase _toggleGroceryProduct;

  Future<Result<GroceryProduct, AppFailure>> getGroceryProduct(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getGroceryProduct.call(
      QueryParams<GroceryProduct>(filter: Eq(GroceryProductFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<GroceryProduct, AppFailure>> updateGroceryProduct(
    String id,
    GroceryProductPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateGroceryProduct.call(
      UpdateParams<String, GroceryProductPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<GroceryProduct, AppFailure>> toggleGroceryProduct(
    String id,
    Field<GroceryProduct, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleGroceryProduct.call(
      ToggleParams<String, Field<GroceryProduct, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
