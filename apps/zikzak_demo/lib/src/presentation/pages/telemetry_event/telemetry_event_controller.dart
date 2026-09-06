// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/telemetry_event/telemetry_event.dart';
import 'telemetry_event_presenter.dart';

class TelemetryEventController extends Controller {
  TelemetryEventController(this._presenter);

  final TelemetryEventPresenter _presenter;

  Future<void> getTelemetryEvent(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getTelemetryEvent(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateTelemetryEvent(
    String id,
    TelemetryEventPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateTelemetryEvent(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleTelemetryEvent(
    String id,
    Field<TelemetryEvent, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleTelemetryEvent(
      id,
      field,
      toggleValue,
      cancelToken,
    );
    result.fold((toggled) {}, (failure) {});
  }

  @override
  void onDisposed() {
    _presenter.dispose();
    super.onDisposed();
  }
}

// END GENERATED
