// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/app_config/app_config.dart';

class AppConfigState {
  const AppConfigState({
    this.error,
    this.appConfig,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single AppConfig entity
  final AppConfig? appConfig;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  AppConfigState copyWith({
    AppFailure? error,
    AppConfig? appConfig,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => AppConfigState(
    error: error ?? this.error,
    appConfig: appConfig ?? this.appConfig,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppConfigState &&
          other.error == error &&
          other.appConfig == appConfig &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      appConfig.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() => 'AppConfigState(error: $error, appConfig: $appConfig)';
}

// END GENERATED
