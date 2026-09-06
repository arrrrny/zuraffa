// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/app_config/app_config.dart';
import '../../../domain/usecases/app_config/get_app_config_usecase.dart';
import '../../../domain/usecases/app_config/toggle_app_config_usecase.dart';
import '../../../domain/usecases/app_config/update_app_config_usecase.dart';

class AppConfigPresenter extends Presenter {
  AppConfigPresenter() {
    _getAppConfig = registerUseCase(getIt<GetAppConfigUseCase>());
    _updateAppConfig = registerUseCase(getIt<UpdateAppConfigUseCase>());
    _toggleAppConfig = registerUseCase(getIt<ToggleAppConfigUseCase>());
  }

  late final GetAppConfigUseCase _getAppConfig;

  late final UpdateAppConfigUseCase _updateAppConfig;

  late final ToggleAppConfigUseCase _toggleAppConfig;

  Future<Result<AppConfig, AppFailure>> getAppConfig(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getAppConfig.call(
      QueryParams<AppConfig>(filter: Eq(AppConfigFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<AppConfig, AppFailure>> updateAppConfig(
    String id,
    AppConfigPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateAppConfig.call(
      UpdateParams<String, AppConfigPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<AppConfig, AppFailure>> toggleAppConfig(
    String id,
    Field<AppConfig, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleAppConfig.call(
      ToggleParams<String, Field<AppConfig, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
