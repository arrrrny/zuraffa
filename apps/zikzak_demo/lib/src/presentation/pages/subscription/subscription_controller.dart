// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/subscription/subscription.dart';
import 'subscription_presenter.dart';

class SubscriptionController extends Controller {
  SubscriptionController(this._presenter);

  final SubscriptionPresenter _presenter;

  Future<void> getSubscription(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getSubscription(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateSubscription(
    String id,
    SubscriptionPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateSubscription(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleSubscription(
    String id,
    Field<Subscription, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleSubscription(
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
