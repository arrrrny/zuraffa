// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/app_notification/app_notification.dart';
import 'app_notification_presenter.dart';

class AppNotificationController extends Controller {
  AppNotificationController(this._presenter);

  final AppNotificationPresenter _presenter;

  Future<void> getAppNotification(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getAppNotification(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateAppNotification(
    String id,
    AppNotificationPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateAppNotification(
      id,
      data,
      cancelToken,
    );
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleAppNotification(
    String id,
    Field<AppNotification, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleAppNotification(
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
