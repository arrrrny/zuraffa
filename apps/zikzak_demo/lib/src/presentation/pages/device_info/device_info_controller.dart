// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/device_info/device_info.dart';
import 'device_info_presenter.dart';

class DeviceInfoController extends Controller {
  DeviceInfoController(this._presenter);

  final DeviceInfoPresenter _presenter;

  Future<void> getDeviceInfo(
    String deviceId, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.getDeviceInfo(deviceId, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateDeviceInfo(
    String deviceId,
    DeviceInfoPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateDeviceInfo(
      deviceId,
      data,
      cancelToken,
    );
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleDeviceInfo(
    String deviceId,
    Field<DeviceInfo, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleDeviceInfo(
      deviceId,
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
