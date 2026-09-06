// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/price_alert/price_alert.dart';
import '../../../domain/usecases/price_alert/get_price_alert_usecase.dart';
import '../../../domain/usecases/price_alert/toggle_price_alert_usecase.dart';
import '../../../domain/usecases/price_alert/update_price_alert_usecase.dart';

class PriceAlertPresenter extends Presenter {
  PriceAlertPresenter() {
    _getPriceAlert = registerUseCase(getIt<GetPriceAlertUseCase>());
    _updatePriceAlert = registerUseCase(getIt<UpdatePriceAlertUseCase>());
    _togglePriceAlert = registerUseCase(getIt<TogglePriceAlertUseCase>());
  }

  late final GetPriceAlertUseCase _getPriceAlert;

  late final UpdatePriceAlertUseCase _updatePriceAlert;

  late final TogglePriceAlertUseCase _togglePriceAlert;

  Future<Result<PriceAlert, AppFailure>> getPriceAlert(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getPriceAlert.call(
      QueryParams<PriceAlert>(filter: Eq(PriceAlertFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<PriceAlert, AppFailure>> updatePriceAlert(
    String id,
    PriceAlertPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updatePriceAlert.call(
      UpdateParams<String, PriceAlertPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<PriceAlert, AppFailure>> togglePriceAlert(
    String id,
    Field<PriceAlert, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _togglePriceAlert.call(
      ToggleParams<String, Field<PriceAlert, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
