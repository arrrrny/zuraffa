// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/zik_zak_config/zik_zak_config_remote_datasource.dart';
import '../../data/repositories/data_zik_zak_config_repository.dart';
import '../../domain/repositories/zik_zak_config_repository.dart';

void registerZikZakConfigRepository(GetIt getIt) {
  getIt.registerLazySingleton<ZikZakConfigRepository>(
    () => DataZikZakConfigRepository(getIt<ZikZakConfigRemoteDataSource>()),
  );
}

// END GENERATED
