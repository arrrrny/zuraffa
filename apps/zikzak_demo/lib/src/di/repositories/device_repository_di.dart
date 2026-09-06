// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/device/device_remote_datasource.dart';
import '../../data/repositories/data_device_repository.dart';
import '../../domain/repositories/device_repository.dart';

void registerDeviceRepository(GetIt getIt) {
  getIt.registerLazySingleton<DeviceRepository>(
    () => DataDeviceRepository(getIt<DeviceRemoteDataSource>()),
  );
}

// END GENERATED
