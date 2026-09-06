// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/zik_zak_score/zik_zak_score_remote_datasource.dart';
import '../../data/repositories/data_zik_zak_score_repository.dart';
import '../../domain/repositories/zik_zak_score_repository.dart';

void registerZikZakScoreRepository(GetIt getIt) {
  getIt.registerLazySingleton<ZikZakScoreRepository>(
    () => DataZikZakScoreRepository(getIt<ZikZakScoreRemoteDataSource>()),
  );
}

// END GENERATED
