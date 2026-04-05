import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/concert/concert_remote_datasource.dart';

void registerConcertRemoteDataSource(GetIt getIt) {
  getIt.registerLazySingleton<ConcertRemoteDataSource>(
    () => ConcertRemoteDataSource(),
  );
}
