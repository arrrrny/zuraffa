// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/auth_request_repository.dart';
import '../../domain/usecases/auth_request/toggle_auth_request_usecase.dart';

void registerToggleAuthRequestUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleAuthRequestUseCase>(
    () => ToggleAuthRequestUseCase(getIt<AuthRequestRepository>()),
  );
}

// END GENERATED
