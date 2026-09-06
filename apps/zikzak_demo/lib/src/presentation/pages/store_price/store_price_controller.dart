// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/store_price/store_price.dart';
import 'store_price_presenter.dart';

class StorePriceController extends Controller {
  StorePriceController(this._presenter);

  final StorePricePresenter _presenter;

  Future<void> getStorePrice(String depotId, [CancelToken? cancelToken]) async {
    final result = await _presenter.getStorePrice(depotId, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateStorePrice(
    String depotId,
    StorePricePatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateStorePrice(
      depotId,
      data,
      cancelToken,
    );
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleStorePrice(
    String depotId,
    Field<StorePrice, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleStorePrice(
      depotId,
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
