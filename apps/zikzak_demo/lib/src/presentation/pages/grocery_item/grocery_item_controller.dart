// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/grocery_item/grocery_item.dart';
import 'grocery_item_presenter.dart';

class GroceryItemController extends Controller {
  GroceryItemController(this._presenter);

  final GroceryItemPresenter _presenter;

  Future<void> getGroceryItem(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getGroceryItem(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateGroceryItem(
    String id,
    GroceryItemPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateGroceryItem(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleGroceryItem(
    String id,
    Field<GroceryItem, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleGroceryItem(
      id,
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
