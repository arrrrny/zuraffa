// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/text_spark/text_spark_remote_datasource.dart';
import '../../data/repositories/data_text_spark_repository.dart';
import '../../domain/repositories/text_spark_repository.dart';

void registerTextSparkRepository(GetIt getIt) {
  getIt.registerLazySingleton<TextSparkRepository>(
    () => DataTextSparkRepository(getIt<TextSparkRemoteDataSource>()),
  );
}

// END GENERATED
