// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/auth_request/auth_request_remote_datasource.dart';
import '../../data/repositories/data_auth_request_repository.dart';
import '../../domain/repositories/auth_request_repository.dart';

void registerAuthRequestRepository(GetIt getIt) {
  getIt.registerLazySingleton<AuthRequestRepository>(
    () => DataAuthRequestRepository(getIt<AuthRequestRemoteDataSource>()),
  );
}

// END GENERATED
