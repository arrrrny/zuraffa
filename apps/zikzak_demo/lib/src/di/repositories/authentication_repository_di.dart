// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/authentication/authentication_remote_datasource.dart';
import '../../data/repositories/data_authentication_repository.dart';
import '../../domain/repositories/authentication_repository.dart';

void registerAuthenticationRepository(GetIt getIt) {
  getIt.registerLazySingleton<AuthenticationRepository>(
    () => DataAuthenticationRepository(getIt<AuthenticationRemoteDataSource>()),
  );
}

// END GENERATED
