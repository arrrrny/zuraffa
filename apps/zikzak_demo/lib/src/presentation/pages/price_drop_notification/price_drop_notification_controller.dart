// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/price_drop_notification/price_drop_notification.dart';
import 'price_drop_notification_presenter.dart';

class PriceDropNotificationController extends Controller {
  PriceDropNotificationController(this._presenter);

  final PriceDropNotificationPresenter _presenter;

  Future<void> getPriceDropNotification(
    String id, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.getPriceDropNotification(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updatePriceDropNotification(
    String id,
    PriceDropNotificationPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updatePriceDropNotification(
      id,
      data,
      cancelToken,
    );
    result.fold((updated) {}, (failure) {});
  }

  Future<void> togglePriceDropNotification(
    String id,
    Field<PriceDropNotification, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.togglePriceDropNotification(
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
