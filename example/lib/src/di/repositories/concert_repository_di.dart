import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/concert/concert_remote_datasource.dart';
import '../../data/repositories/data_concert_repository.dart';
import '../../domain/repositories/concert_repository.dart';

void registerConcertRepository(GetIt getIt) {
  getIt.registerLazySingleton<ConcertRepository>(
    () => DataConcertRepository(getIt<ConcertRemoteDataSource>()),
  );
}
