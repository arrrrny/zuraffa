// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/connected_account_repository.dart';
import '../../domain/usecases/connected_account/toggle_connected_account_usecase.dart';

void registerToggleConnectedAccountUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleConnectedAccountUseCase>(
    () => ToggleConnectedAccountUseCase(getIt<ConnectedAccountRepository>()),
  );
}

// END GENERATED
