// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/zik_zak/zik_zak_remote_datasource.dart';
import '../../data/repositories/data_zik_zak_repository.dart';
import '../../domain/repositories/zik_zak_repository.dart';

void registerZikZakRepository(GetIt getIt) {
  getIt.registerLazySingleton<ZikZakRepository>(
    () => DataZikZakRepository(getIt<ZikZakRemoteDataSource>()),
  );
}

// END GENERATED
