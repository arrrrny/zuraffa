// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/device_info_repository.dart';
import '../../domain/usecases/device_info/get_device_info_usecase.dart';

void registerGetDeviceInfoUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetDeviceInfoUseCase>(
    () => GetDeviceInfoUseCase(getIt<DeviceInfoRepository>()),
  );
}

// END GENERATED
