// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/device_info_repository.dart';
import '../../domain/usecases/device_info/toggle_device_info_usecase.dart';

void registerToggleDeviceInfoUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleDeviceInfoUseCase>(
    () => ToggleDeviceInfoUseCase(getIt<DeviceInfoRepository>()),
  );
}

// END GENERATED
