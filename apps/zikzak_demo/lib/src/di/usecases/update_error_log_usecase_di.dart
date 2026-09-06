// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/error_log_repository.dart';
import '../../domain/usecases/error_log/update_error_log_usecase.dart';

void registerUpdateErrorLogUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateErrorLogUseCase>(
    () => UpdateErrorLogUseCase(getIt<ErrorLogRepository>()),
  );
}

// END GENERATED
