// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/error_log/error_log.dart';

class ErrorLogState {
  const ErrorLogState({
    this.error,
    this.errorLog,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single ErrorLog entity
  final ErrorLog? errorLog;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  ErrorLogState copyWith({
    AppFailure? error,
    ErrorLog? errorLog,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => ErrorLogState(
    error: error ?? this.error,
    errorLog: errorLog ?? this.errorLog,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ErrorLogState &&
          other.error == error &&
          other.errorLog == errorLog &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      errorLog.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() => 'ErrorLogState(error: $error, errorLog: $errorLog)';
}

// END GENERATED
