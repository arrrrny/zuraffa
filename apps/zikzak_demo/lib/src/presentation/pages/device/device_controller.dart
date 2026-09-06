// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/device/device.dart';
import 'device_presenter.dart';

class DeviceController extends Controller {
  DeviceController(this._presenter);

  final DevicePresenter _presenter;

  Future<void> getDevice(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getDevice(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateDevice(
    String id,
    DevicePatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateDevice(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleDevice(
    String id,
    Field<Device, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleDevice(
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
