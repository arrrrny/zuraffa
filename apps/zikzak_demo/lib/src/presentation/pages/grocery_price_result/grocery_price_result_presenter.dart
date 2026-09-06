// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/grocery_price_result/grocery_price_result.dart';
import '../../../domain/usecases/grocery_price_result/get_grocery_price_result_usecase.dart';
import '../../../domain/usecases/grocery_price_result/toggle_grocery_price_result_usecase.dart';
import '../../../domain/usecases/grocery_price_result/update_grocery_price_result_usecase.dart';

class GroceryPriceResultPresenter extends Presenter {
  GroceryPriceResultPresenter() {
    _getGroceryPriceResult = registerUseCase(
      getIt<GetGroceryPriceResultUseCase>(),
    );
    _updateGroceryPriceResult = registerUseCase(
      getIt<UpdateGroceryPriceResultUseCase>(),
    );
    _toggleGroceryPriceResult = registerUseCase(
      getIt<ToggleGroceryPriceResultUseCase>(),
    );
  }

  late final GetGroceryPriceResultUseCase _getGroceryPriceResult;

  late final UpdateGroceryPriceResultUseCase _updateGroceryPriceResult;

  late final ToggleGroceryPriceResultUseCase _toggleGroceryPriceResult;

  Future<Result<GroceryPriceResult, AppFailure>> getGroceryPriceResult(
    String storeName, [
    CancelToken? cancelToken,
  ]) {
    return _getGroceryPriceResult.call(
      QueryParams<GroceryPriceResult>(
        filter: Eq(GroceryPriceResultFields.storeName, storeName),
      ),
      cancelToken: cancelToken,
    );
  }

  Future<Result<GroceryPriceResult, AppFailure>> updateGroceryPriceResult(
    String storeName,
    GroceryPriceResultPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateGroceryPriceResult.call(
      UpdateParams<String, GroceryPriceResultPatch>(id: storeName, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<GroceryPriceResult, AppFailure>> toggleGroceryPriceResult(
    String storeName,
    Field<GroceryPriceResult, dynamic> field,
    bool value, [
    CancelToken? cancelToken,
  ]) {
    return _toggleGroceryPriceResult.call(
      ToggleParams<String, Field<GroceryPriceResult, dynamic>>(
        id: storeName,
        field: field,
        value: value,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
