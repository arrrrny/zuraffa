// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/telemetry_event/telemetry_event.dart';

abstract class TelemetryEventDataSource with Loggable, FailureHandler {
  Future<TelemetryEvent> get(QueryParams<TelemetryEvent> params);
  Future<TelemetryEvent> update(
    UpdateParams<String, TelemetryEventPatch> params,
  );
  Future<TelemetryEvent> toggle(
    ToggleParams<String, Field<TelemetryEvent, dynamic>> params,
  );
}

// END GENERATED
