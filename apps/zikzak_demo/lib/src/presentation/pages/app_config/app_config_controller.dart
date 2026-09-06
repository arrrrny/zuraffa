// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/app_config/app_config.dart';
import 'app_config_presenter.dart';

class AppConfigController extends Controller {
  AppConfigController(this._presenter);

  final AppConfigPresenter _presenter;

  Future<void> getAppConfig(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getAppConfig(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateAppConfig(
    String id,
    AppConfigPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateAppConfig(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleAppConfig(
    String id,
    Field<AppConfig, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleAppConfig(
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
