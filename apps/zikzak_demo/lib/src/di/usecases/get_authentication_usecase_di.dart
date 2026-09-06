// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/authentication_repository.dart';
import '../../domain/usecases/authentication/get_authentication_usecase.dart';

void registerGetAuthenticationUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetAuthenticationUseCase>(
    () => GetAuthenticationUseCase(getIt<AuthenticationRepository>()),
  );
}

// END GENERATED
