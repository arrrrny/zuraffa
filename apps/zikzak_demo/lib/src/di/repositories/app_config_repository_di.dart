// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/app_config/app_config_remote_datasource.dart';
import '../../data/repositories/data_app_config_repository.dart';
import '../../domain/repositories/app_config_repository.dart';

void registerAppConfigRepository(GetIt getIt) {
  getIt.registerLazySingleton<AppConfigRepository>(
    () => DataAppConfigRepository(getIt<AppConfigRemoteDataSource>()),
  );
}

// END GENERATED
