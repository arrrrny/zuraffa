// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/zik_zak_config/zik_zak_config.dart';
import '../../../domain/usecases/zik_zak_config/get_zik_zak_config_usecase.dart';
import '../../../domain/usecases/zik_zak_config/toggle_zik_zak_config_usecase.dart';
import '../../../domain/usecases/zik_zak_config/update_zik_zak_config_usecase.dart';

class ZikZakConfigPresenter extends Presenter {
  ZikZakConfigPresenter() {
    _getZikZakConfig = registerUseCase(getIt<GetZikZakConfigUseCase>());
    _updateZikZakConfig = registerUseCase(getIt<UpdateZikZakConfigUseCase>());
    _toggleZikZakConfig = registerUseCase(getIt<ToggleZikZakConfigUseCase>());
  }

  late final GetZikZakConfigUseCase _getZikZakConfig;

  late final UpdateZikZakConfigUseCase _updateZikZakConfig;

  late final ToggleZikZakConfigUseCase _toggleZikZakConfig;

  Future<Result<ZikZakConfig, AppFailure>> getZikZakConfig(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getZikZakConfig.call(
      QueryParams<ZikZakConfig>(filter: Eq(ZikZakConfigFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<ZikZakConfig, AppFailure>> updateZikZakConfig(
    String id,
    ZikZakConfigPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateZikZakConfig.call(
      UpdateParams<String, ZikZakConfigPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<ZikZakConfig, AppFailure>> toggleZikZakConfig(
    String id,
    Field<ZikZakConfig, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleZikZakConfig.call(
      ToggleParams<String, Field<ZikZakConfig, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
