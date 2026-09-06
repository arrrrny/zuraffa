// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/connected_account_repository.dart';
import '../../domain/usecases/connected_account/update_connected_account_usecase.dart';

void registerUpdateConnectedAccountUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateConnectedAccountUseCase>(
    () => UpdateConnectedAccountUseCase(getIt<ConnectedAccountRepository>()),
  );
}

// END GENERATED
