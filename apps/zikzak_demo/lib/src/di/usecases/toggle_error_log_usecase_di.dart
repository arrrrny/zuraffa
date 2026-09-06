// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/error_log_repository.dart';
import '../../domain/usecases/error_log/toggle_error_log_usecase.dart';

void registerToggleErrorLogUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleErrorLogUseCase>(
    () => ToggleErrorLogUseCase(getIt<ErrorLogRepository>()),
  );
}

// END GENERATED
