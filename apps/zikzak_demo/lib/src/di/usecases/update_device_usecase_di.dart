// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/device_repository.dart';
import '../../domain/usecases/device/update_device_usecase.dart';

void registerUpdateDeviceUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateDeviceUseCase>(
    () => UpdateDeviceUseCase(getIt<DeviceRepository>()),
  );
}

// END GENERATED
