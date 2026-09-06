// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/telemetry_event_repository.dart';
import '../../domain/usecases/telemetry_event/update_telemetry_event_usecase.dart';

void registerUpdateTelemetryEventUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateTelemetryEventUseCase>(
    () => UpdateTelemetryEventUseCase(getIt<TelemetryEventRepository>()),
  );
}

// END GENERATED
