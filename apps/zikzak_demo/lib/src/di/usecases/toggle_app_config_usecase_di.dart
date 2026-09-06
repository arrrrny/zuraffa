// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/app_config_repository.dart';
import '../../domain/usecases/app_config/toggle_app_config_usecase.dart';

void registerToggleAppConfigUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleAppConfigUseCase>(
    () => ToggleAppConfigUseCase(getIt<AppConfigRepository>()),
  );
}

// END GENERATED
