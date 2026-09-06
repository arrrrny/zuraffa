// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/app_config_repository.dart';
import '../../domain/usecases/app_config/get_app_config_usecase.dart';

void registerGetAppConfigUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetAppConfigUseCase>(
    () => GetAppConfigUseCase(getIt<AppConfigRepository>()),
  );
}

// END GENERATED
