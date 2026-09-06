// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/price_alert/price_alert.dart';
import 'price_alert_presenter.dart';

class PriceAlertController extends Controller {
  PriceAlertController(this._presenter);

  final PriceAlertPresenter _presenter;

  Future<void> getPriceAlert(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getPriceAlert(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updatePriceAlert(
    String id,
    PriceAlertPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updatePriceAlert(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> togglePriceAlert(
    String id,
    Field<PriceAlert, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.togglePriceAlert(
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
