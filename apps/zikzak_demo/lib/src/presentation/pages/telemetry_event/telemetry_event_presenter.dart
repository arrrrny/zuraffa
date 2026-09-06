// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/telemetry_event/telemetry_event.dart';
import '../../../domain/usecases/telemetry_event/get_telemetry_event_usecase.dart';
import '../../../domain/usecases/telemetry_event/toggle_telemetry_event_usecase.dart';
import '../../../domain/usecases/telemetry_event/update_telemetry_event_usecase.dart';

class TelemetryEventPresenter extends Presenter {
  TelemetryEventPresenter() {
    _getTelemetryEvent = registerUseCase(getIt<GetTelemetryEventUseCase>());
    _updateTelemetryEvent = registerUseCase(
      getIt<UpdateTelemetryEventUseCase>(),
    );
    _toggleTelemetryEvent = registerUseCase(
      getIt<ToggleTelemetryEventUseCase>(),
    );
  }

  late final GetTelemetryEventUseCase _getTelemetryEvent;

  late final UpdateTelemetryEventUseCase _updateTelemetryEvent;

  late final ToggleTelemetryEventUseCase _toggleTelemetryEvent;

  Future<Result<TelemetryEvent, AppFailure>> getTelemetryEvent(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getTelemetryEvent.call(
      QueryParams<TelemetryEvent>(filter: Eq(TelemetryEventFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<TelemetryEvent, AppFailure>> updateTelemetryEvent(
    String id,
    TelemetryEventPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateTelemetryEvent.call(
      UpdateParams<String, TelemetryEventPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<TelemetryEvent, AppFailure>> toggleTelemetryEvent(
    String id,
    Field<TelemetryEvent, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleTelemetryEvent.call(
      ToggleParams<String, Field<TelemetryEvent, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
