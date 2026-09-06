// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/telemetry_event/telemetry_event_remote_datasource.dart';
import '../../data/repositories/data_telemetry_event_repository.dart';
import '../../domain/repositories/telemetry_event_repository.dart';

void registerTelemetryEventRepository(GetIt getIt) {
  getIt.registerLazySingleton<TelemetryEventRepository>(
    () => DataTelemetryEventRepository(getIt<TelemetryEventRemoteDataSource>()),
  );
}

// END GENERATED
