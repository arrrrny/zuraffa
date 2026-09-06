// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/auth_request_repository.dart';
import '../../domain/usecases/auth_request/get_auth_request_usecase.dart';

void registerGetAuthRequestUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetAuthRequestUseCase>(
    () => GetAuthRequestUseCase(getIt<AuthRequestRepository>()),
  );
}

// END GENERATED
