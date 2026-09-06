// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/grocery_sub_variety/grocery_sub_variety.dart';
import 'grocery_sub_variety_presenter.dart';

class GrocerySubVarietyController extends Controller {
  GrocerySubVarietyController(this._presenter);

  final GrocerySubVarietyPresenter _presenter;

  Future<void> getGrocerySubVariety(
    String id, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.getGrocerySubVariety(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateGrocerySubVariety(
    String id,
    GrocerySubVarietyPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateGrocerySubVariety(
      id,
      data,
      cancelToken,
    );
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleGrocerySubVariety(
    String id,
    Field<GrocerySubVariety, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleGrocerySubVariety(
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
