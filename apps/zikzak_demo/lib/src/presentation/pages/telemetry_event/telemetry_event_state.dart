// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/telemetry_event/telemetry_event.dart';

class TelemetryEventState {
  const TelemetryEventState({
    this.error,
    this.telemetryEvent,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single TelemetryEvent entity
  final TelemetryEvent? telemetryEvent;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  TelemetryEventState copyWith({
    AppFailure? error,
    TelemetryEvent? telemetryEvent,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => TelemetryEventState(
    error: error ?? this.error,
    telemetryEvent: telemetryEvent ?? this.telemetryEvent,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TelemetryEventState &&
          other.error == error &&
          other.telemetryEvent == telemetryEvent &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      telemetryEvent.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'TelemetryEventState(error: $error, telemetryEvent: $telemetryEvent)';
}

// END GENERATED
