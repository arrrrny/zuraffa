// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/grocery_price_result/grocery_price_result.dart';
import 'grocery_price_result_presenter.dart';

class GroceryPriceResultController extends Controller {
  GroceryPriceResultController(this._presenter);

  final GroceryPriceResultPresenter _presenter;

  Future<void> getGroceryPriceResult(
    String storeName, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.getGroceryPriceResult(
      storeName,
      cancelToken,
    );
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateGroceryPriceResult(
    String storeName,
    GroceryPriceResultPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateGroceryPriceResult(
      storeName,
      data,
      cancelToken,
    );
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleGroceryPriceResult(
    String storeName,
    Field<GroceryPriceResult, dynamic> field,
    bool value, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleGroceryPriceResult(
      storeName,
      field,
      value,
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
