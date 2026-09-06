// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/device_info/device_info.dart';
import '../../../domain/usecases/device_info/get_device_info_usecase.dart';
import '../../../domain/usecases/device_info/toggle_device_info_usecase.dart';
import '../../../domain/usecases/device_info/update_device_info_usecase.dart';

class DeviceInfoPresenter extends Presenter {
  DeviceInfoPresenter() {
    _getDeviceInfo = registerUseCase(getIt<GetDeviceInfoUseCase>());
    _updateDeviceInfo = registerUseCase(getIt<UpdateDeviceInfoUseCase>());
    _toggleDeviceInfo = registerUseCase(getIt<ToggleDeviceInfoUseCase>());
  }

  late final GetDeviceInfoUseCase _getDeviceInfo;

  late final UpdateDeviceInfoUseCase _updateDeviceInfo;

  late final ToggleDeviceInfoUseCase _toggleDeviceInfo;

  Future<Result<DeviceInfo, AppFailure>> getDeviceInfo(
    String deviceId, [
    CancelToken? cancelToken,
  ]) {
    return _getDeviceInfo.call(
      QueryParams<DeviceInfo>(filter: Eq(DeviceInfoFields.deviceId, deviceId)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<DeviceInfo, AppFailure>> updateDeviceInfo(
    String deviceId,
    DeviceInfoPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateDeviceInfo.call(
      UpdateParams<String, DeviceInfoPatch>(id: deviceId, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<DeviceInfo, AppFailure>> toggleDeviceInfo(
    String deviceId,
    Field<DeviceInfo, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleDeviceInfo.call(
      ToggleParams<String, Field<DeviceInfo, dynamic>>(
        id: deviceId,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
