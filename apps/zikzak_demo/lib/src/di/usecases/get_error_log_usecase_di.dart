// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/error_log_repository.dart';
import '../../domain/usecases/error_log/get_error_log_usecase.dart';

void registerGetErrorLogUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetErrorLogUseCase>(
    () => GetErrorLogUseCase(getIt<ErrorLogRepository>()),
  );
}

// END GENERATED
