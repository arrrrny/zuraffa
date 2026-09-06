// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/device_repository.dart';
import '../../domain/usecases/device/toggle_device_usecase.dart';

void registerToggleDeviceUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleDeviceUseCase>(
    () => ToggleDeviceUseCase(getIt<DeviceRepository>()),
  );
}

// END GENERATED
