// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/user/user_remote_datasource.dart';
import '../../data/repositories/data_user_repository.dart';
import '../../domain/repositories/user_repository.dart';

void registerUserRepository(GetIt getIt) {
  getIt.registerLazySingleton<UserRepository>(
    () => DataUserRepository(getIt<UserRemoteDataSource>()),
  );
}

// END GENERATED
