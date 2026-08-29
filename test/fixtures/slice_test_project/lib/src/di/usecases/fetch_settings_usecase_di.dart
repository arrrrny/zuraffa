/// DI registration for FetchSettingsUseCase (fixture for spec 043).
library;

import 'package:get_it/get_it.dart';

import '../../domain/usecases/shared/fetch_settings_usecase.dart';

/// Registers [FetchSettingsUseCase].
void registerFetchSettingsUseCase(GetIt getIt) {
  getIt.registerLazySingleton<FetchSettingsUseCase>(
    () => const FetchSettingsUseCase(),
  );
}
