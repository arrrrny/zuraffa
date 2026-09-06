// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/authentication_repository.dart';
import '../../domain/usecases/authentication/update_authentication_usecase.dart';

void registerUpdateAuthenticationUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateAuthenticationUseCase>(
    () => UpdateAuthenticationUseCase(getIt<AuthenticationRepository>()),
  );
}

// END GENERATED
