// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/device_info/device_info.dart';
import 'device_info_datasource.dart';

class DeviceInfoRemoteDataSource
    with Loggable, FailureHandler
    implements DeviceInfoDataSource {
  @override
  Future<DeviceInfo> get(QueryParams<DeviceInfo> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<DeviceInfo> update(
    UpdateParams<String, DeviceInfoPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<DeviceInfo> toggle(
    ToggleParams<String, Field<DeviceInfo, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
