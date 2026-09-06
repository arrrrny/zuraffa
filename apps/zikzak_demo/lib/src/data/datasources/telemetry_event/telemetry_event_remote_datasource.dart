// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/telemetry_event/telemetry_event.dart';
import 'telemetry_event_datasource.dart';

class TelemetryEventRemoteDataSource
    with Loggable, FailureHandler
    implements TelemetryEventDataSource {
  @override
  Future<TelemetryEvent> get(QueryParams<TelemetryEvent> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<TelemetryEvent> update(
    UpdateParams<String, TelemetryEventPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<TelemetryEvent> toggle(
    ToggleParams<String, Field<TelemetryEvent, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
