// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/url_spark/url_spark_remote_datasource.dart';
import '../../data/repositories/data_url_spark_repository.dart';
import '../../domain/repositories/url_spark_repository.dart';

void registerUrlSparkRepository(GetIt getIt) {
  getIt.registerLazySingleton<UrlSparkRepository>(
    () => DataUrlSparkRepository(getIt<UrlSparkRemoteDataSource>()),
  );
}

// END GENERATED
