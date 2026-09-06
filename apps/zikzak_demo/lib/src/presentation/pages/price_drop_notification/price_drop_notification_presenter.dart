// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/price_drop_notification/price_drop_notification.dart';
import '../../../domain/usecases/price_drop_notification/get_price_drop_notification_usecase.dart';
import '../../../domain/usecases/price_drop_notification/toggle_price_drop_notification_usecase.dart';
import '../../../domain/usecases/price_drop_notification/update_price_drop_notification_usecase.dart';

class PriceDropNotificationPresenter extends Presenter {
  PriceDropNotificationPresenter() {
    _getPriceDropNotification = registerUseCase(
      getIt<GetPriceDropNotificationUseCase>(),
    );
    _updatePriceDropNotification = registerUseCase(
      getIt<UpdatePriceDropNotificationUseCase>(),
    );
    _togglePriceDropNotification = registerUseCase(
      getIt<TogglePriceDropNotificationUseCase>(),
    );
  }

  late final GetPriceDropNotificationUseCase _getPriceDropNotification;

  late final UpdatePriceDropNotificationUseCase _updatePriceDropNotification;

  late final TogglePriceDropNotificationUseCase _togglePriceDropNotification;

  Future<Result<PriceDropNotification, AppFailure>> getPriceDropNotification(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getPriceDropNotification.call(
      QueryParams<PriceDropNotification>(
        filter: Eq(PriceDropNotificationFields.id, id),
      ),
      cancelToken: cancelToken,
    );
  }

  Future<Result<PriceDropNotification, AppFailure>> updatePriceDropNotification(
    String id,
    PriceDropNotificationPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updatePriceDropNotification.call(
      UpdateParams<String, PriceDropNotificationPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<PriceDropNotification, AppFailure>> togglePriceDropNotification(
    String id,
    Field<PriceDropNotification, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _togglePriceDropNotification.call(
      ToggleParams<String, Field<PriceDropNotification, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
