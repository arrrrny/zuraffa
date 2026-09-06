// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/grocery_price_comparison/grocery_price_comparison.dart';
import 'grocery_price_comparison_presenter.dart';

class GroceryPriceComparisonController extends Controller {
  GroceryPriceComparisonController(this._presenter);

  final GroceryPriceComparisonPresenter _presenter;

  Future<void> getGroceryPriceComparison(
    String itemId, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.getGroceryPriceComparison(
      itemId,
      cancelToken,
    );
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateGroceryPriceComparison(
    String itemId,
    GroceryPriceComparisonPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateGroceryPriceComparison(
      itemId,
      data,
      cancelToken,
    );
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleGroceryPriceComparison(
    String itemId,
    Field<GroceryPriceComparison, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleGroceryPriceComparison(
      itemId,
      field,
      toggleValue,
      cancelToken,
    );
    result.fold((toggled) {}, (failure) {});
  }

  @override
  void onDisposed() {
    _presenter.dispose();
    super.onDisposed();
  }
}

// END GENERATED
