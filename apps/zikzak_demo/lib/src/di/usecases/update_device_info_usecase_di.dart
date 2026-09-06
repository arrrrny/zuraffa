// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/device_info_repository.dart';
import '../../domain/usecases/device_info/update_device_info_usecase.dart';

void registerUpdateDeviceInfoUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateDeviceInfoUseCase>(
    () => UpdateDeviceInfoUseCase(getIt<DeviceInfoRepository>()),
  );
}

// END GENERATED
