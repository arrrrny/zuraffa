// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/app_notification/app_notification.dart';
import '../../../domain/usecases/app_notification/get_app_notification_usecase.dart';
import '../../../domain/usecases/app_notification/toggle_app_notification_usecase.dart';
import '../../../domain/usecases/app_notification/update_app_notification_usecase.dart';

class AppNotificationPresenter extends Presenter {
  AppNotificationPresenter() {
    _getAppNotification = registerUseCase(getIt<GetAppNotificationUseCase>());
    _updateAppNotification = registerUseCase(
      getIt<UpdateAppNotificationUseCase>(),
    );
    _toggleAppNotification = registerUseCase(
      getIt<ToggleAppNotificationUseCase>(),
    );
  }

  late final GetAppNotificationUseCase _getAppNotification;

  late final UpdateAppNotificationUseCase _updateAppNotification;

  late final ToggleAppNotificationUseCase _toggleAppNotification;

  Future<Result<AppNotification, AppFailure>> getAppNotification(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getAppNotification.call(
      QueryParams<AppNotification>(filter: Eq(AppNotificationFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<AppNotification, AppFailure>> updateAppNotification(
    String id,
    AppNotificationPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateAppNotification.call(
      UpdateParams<String, AppNotificationPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<AppNotification, AppFailure>> toggleAppNotification(
    String id,
    Field<AppNotification, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleAppNotification.call(
      ToggleParams<String, Field<AppNotification, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
