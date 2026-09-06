// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/authentication_repository.dart';
import '../../domain/usecases/authentication/toggle_authentication_usecase.dart';

void registerToggleAuthenticationUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleAuthenticationUseCase>(
    () => ToggleAuthenticationUseCase(getIt<AuthenticationRepository>()),
  );
}

// END GENERATED
