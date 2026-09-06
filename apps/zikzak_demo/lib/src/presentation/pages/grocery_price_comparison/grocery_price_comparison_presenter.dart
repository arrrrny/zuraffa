// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/grocery_price_comparison/grocery_price_comparison.dart';
import '../../../domain/usecases/grocery_price_comparison/get_grocery_price_comparison_usecase.dart';
import '../../../domain/usecases/grocery_price_comparison/toggle_grocery_price_comparison_usecase.dart';
import '../../../domain/usecases/grocery_price_comparison/update_grocery_price_comparison_usecase.dart';

class GroceryPriceComparisonPresenter extends Presenter {
  GroceryPriceComparisonPresenter() {
    _getGroceryPriceComparison = registerUseCase(
      getIt<GetGroceryPriceComparisonUseCase>(),
    );
    _updateGroceryPriceComparison = registerUseCase(
      getIt<UpdateGroceryPriceComparisonUseCase>(),
    );
    _toggleGroceryPriceComparison = registerUseCase(
      getIt<ToggleGroceryPriceComparisonUseCase>(),
    );
  }

  late final GetGroceryPriceComparisonUseCase _getGroceryPriceComparison;

  late final UpdateGroceryPriceComparisonUseCase _updateGroceryPriceComparison;

  late final ToggleGroceryPriceComparisonUseCase _toggleGroceryPriceComparison;

  Future<Result<GroceryPriceComparison, AppFailure>> getGroceryPriceComparison(
    String itemId, [
    CancelToken? cancelToken,
  ]) {
    return _getGroceryPriceComparison.call(
      QueryParams<GroceryPriceComparison>(
        filter: Eq(GroceryPriceComparisonFields.itemId, itemId),
      ),
      cancelToken: cancelToken,
    );
  }

  Future<Result<GroceryPriceComparison, AppFailure>>
  updateGroceryPriceComparison(
    String itemId,
    GroceryPriceComparisonPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateGroceryPriceComparison.call(
      UpdateParams<String, GroceryPriceComparisonPatch>(id: itemId, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<GroceryPriceComparison, AppFailure>>
  toggleGroceryPriceComparison(
    String itemId,
    Field<GroceryPriceComparison, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleGroceryPriceComparison.call(
      ToggleParams<String, Field<GroceryPriceComparison, dynamic>>(
        id: itemId,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
