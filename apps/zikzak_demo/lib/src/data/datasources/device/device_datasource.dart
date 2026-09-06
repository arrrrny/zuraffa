// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/device/device.dart';

abstract class DeviceDataSource with Loggable, FailureHandler {
  Future<Device> get(QueryParams<Device> params);
  Future<Device> update(UpdateParams<String, DevicePatch> params);
  Future<Device> toggle(ToggleParams<String, Field<Device, dynamic>> params);
}

// END GENERATED
