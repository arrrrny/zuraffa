// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/device/device.dart';
import '../../../domain/usecases/device/get_device_usecase.dart';
import '../../../domain/usecases/device/toggle_device_usecase.dart';
import '../../../domain/usecases/device/update_device_usecase.dart';

class DevicePresenter extends Presenter {
  DevicePresenter() {
    _getDevice = registerUseCase(getIt<GetDeviceUseCase>());
    _updateDevice = registerUseCase(getIt<UpdateDeviceUseCase>());
    _toggleDevice = registerUseCase(getIt<ToggleDeviceUseCase>());
  }

  late final GetDeviceUseCase _getDevice;

  late final UpdateDeviceUseCase _updateDevice;

  late final ToggleDeviceUseCase _toggleDevice;

  Future<Result<Device, AppFailure>> getDevice(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getDevice.call(
      QueryParams<Device>(filter: Eq(DeviceFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<Device, AppFailure>> updateDevice(
    String id,
    DevicePatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateDevice.call(
      UpdateParams<String, DevicePatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<Device, AppFailure>> toggleDevice(
    String id,
    Field<Device, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleDevice.call(
      ToggleParams<String, Field<Device, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
