// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/auth_request_repository.dart';
import '../../domain/usecases/auth_request/update_auth_request_usecase.dart';

void registerUpdateAuthRequestUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateAuthRequestUseCase>(
    () => UpdateAuthRequestUseCase(getIt<AuthRequestRepository>()),
  );
}

// END GENERATED
