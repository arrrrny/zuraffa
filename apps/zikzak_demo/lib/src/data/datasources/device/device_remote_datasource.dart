// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/device/device.dart';
import 'device_datasource.dart';

class DeviceRemoteDataSource
    with Loggable, FailureHandler
    implements DeviceDataSource {
  @override
  Future<Device> get(QueryParams<Device> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<Device> update(UpdateParams<String, DevicePatch> params) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<Device> toggle(
    ToggleParams<String, Field<Device, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
