// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/nearby_grocery_store/nearby_grocery_store.dart';
import 'nearby_grocery_store_presenter.dart';

class NearbyGroceryStoreController extends Controller {
  NearbyGroceryStoreController(this._presenter);

  final NearbyGroceryStorePresenter _presenter;

  Future<void> getNearbyGroceryStore(
    String id, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.getNearbyGroceryStore(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateNearbyGroceryStore(
    String id,
    NearbyGroceryStorePatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateNearbyGroceryStore(
      id,
      data,
      cancelToken,
    );
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleNearbyGroceryStore(
    String id,
    Field<NearbyGroceryStore, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleNearbyGroceryStore(
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
