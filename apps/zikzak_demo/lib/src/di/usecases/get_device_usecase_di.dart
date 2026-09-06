// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/device_repository.dart';
import '../../domain/usecases/device/get_device_usecase.dart';

void registerGetDeviceUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetDeviceUseCase>(
    () => GetDeviceUseCase(getIt<DeviceRepository>()),
  );
}

// END GENERATED
