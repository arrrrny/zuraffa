// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/error_log/error_log_remote_datasource.dart';
import '../../data/repositories/data_error_log_repository.dart';
import '../../domain/repositories/error_log_repository.dart';

void registerErrorLogRepository(GetIt getIt) {
  getIt.registerLazySingleton<ErrorLogRepository>(
    () => DataErrorLogRepository(getIt<ErrorLogRemoteDataSource>()),
  );
}

// END GENERATED
