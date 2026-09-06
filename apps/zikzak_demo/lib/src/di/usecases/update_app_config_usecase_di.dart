// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/app_config_repository.dart';
import '../../domain/usecases/app_config/update_app_config_usecase.dart';

void registerUpdateAppConfigUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateAppConfigUseCase>(
    () => UpdateAppConfigUseCase(getIt<AppConfigRepository>()),
  );
}

// END GENERATED
