// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/connected_account/connected_account_remote_datasource.dart';
import '../../data/repositories/data_connected_account_repository.dart';
import '../../domain/repositories/connected_account_repository.dart';

void registerConnectedAccountRepository(GetIt getIt) {
  getIt.registerLazySingleton<ConnectedAccountRepository>(
    () => DataConnectedAccountRepository(
      getIt<ConnectedAccountRemoteDataSource>(),
    ),
  );
}

// END GENERATED
