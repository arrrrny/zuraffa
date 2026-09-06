// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/device_info/device_info_remote_datasource.dart';
import '../../data/repositories/data_device_info_repository.dart';
import '../../domain/repositories/device_info_repository.dart';

void registerDeviceInfoRepository(GetIt getIt) {
  getIt.registerLazySingleton<DeviceInfoRepository>(
    () => DataDeviceInfoRepository(getIt<DeviceInfoRemoteDataSource>()),
  );
}

// END GENERATED
