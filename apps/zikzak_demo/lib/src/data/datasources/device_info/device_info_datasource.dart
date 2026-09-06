// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/device_info/device_info.dart';

abstract class DeviceInfoDataSource with Loggable, FailureHandler {
  Future<DeviceInfo> get(QueryParams<DeviceInfo> params);
  Future<DeviceInfo> update(UpdateParams<String, DeviceInfoPatch> params);
  Future<DeviceInfo> toggle(
    ToggleParams<String, Field<DeviceInfo, dynamic>> params,
  );
}

// END GENERATED
