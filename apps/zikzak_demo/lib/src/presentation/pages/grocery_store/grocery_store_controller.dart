// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/grocery_store/grocery_store.dart';
import 'grocery_store_presenter.dart';

class GroceryStoreController extends Controller {
  GroceryStoreController(this._presenter);

  final GroceryStorePresenter _presenter;

  Future<void> getGroceryStore(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getGroceryStore(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateGroceryStore(
    String id,
    GroceryStorePatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateGroceryStore(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleGroceryStore(
    String id,
    Field<GroceryStore, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleGroceryStore(
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
