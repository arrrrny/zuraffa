// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/connected_account_repository.dart';
import '../../domain/usecases/connected_account/get_connected_account_usecase.dart';

void registerGetConnectedAccountUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetConnectedAccountUseCase>(
    () => GetConnectedAccountUseCase(getIt<ConnectedAccountRepository>()),
  );
}

// END GENERATED
