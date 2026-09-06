// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/telemetry_event_repository.dart';
import '../../domain/usecases/telemetry_event/get_telemetry_event_usecase.dart';

void registerGetTelemetryEventUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetTelemetryEventUseCase>(
    () => GetTelemetryEventUseCase(getIt<TelemetryEventRepository>()),
  );
}

// END GENERATED
