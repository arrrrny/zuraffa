// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/telemetry_event_repository.dart';
import '../../domain/usecases/telemetry_event/toggle_telemetry_event_usecase.dart';

void registerToggleTelemetryEventUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleTelemetryEventUseCase>(
    () => ToggleTelemetryEventUseCase(getIt<TelemetryEventRepository>()),
  );
}

// END GENERATED
