// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/subscription/subscription.dart';
import '../../../domain/usecases/subscription/get_subscription_usecase.dart';
import '../../../domain/usecases/subscription/toggle_subscription_usecase.dart';
import '../../../domain/usecases/subscription/update_subscription_usecase.dart';

class SubscriptionPresenter extends Presenter {
  SubscriptionPresenter() {
    _getSubscription = registerUseCase(getIt<GetSubscriptionUseCase>());
    _updateSubscription = registerUseCase(getIt<UpdateSubscriptionUseCase>());
    _toggleSubscription = registerUseCase(getIt<ToggleSubscriptionUseCase>());
  }

  late final GetSubscriptionUseCase _getSubscription;

  late final UpdateSubscriptionUseCase _updateSubscription;

  late final ToggleSubscriptionUseCase _toggleSubscription;

  Future<Result<Subscription, AppFailure>> getSubscription(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getSubscription.call(
      QueryParams<Subscription>(filter: Eq(SubscriptionFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<Subscription, AppFailure>> updateSubscription(
    String id,
    SubscriptionPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateSubscription.call(
      UpdateParams<String, SubscriptionPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<Subscription, AppFailure>> toggleSubscription(
    String id,
    Field<Subscription, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleSubscription.call(
      ToggleParams<String, Field<Subscription, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
