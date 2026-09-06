// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/app_notification/app_notification.dart';

class AppNotificationState {
  const AppNotificationState({
    this.error,
    this.appNotification,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single AppNotification entity
  final AppNotification? appNotification;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  AppNotificationState copyWith({
    AppFailure? error,
    AppNotification? appNotification,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => AppNotificationState(
    error: error ?? this.error,
    appNotification: appNotification ?? this.appNotification,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotificationState &&
          other.error == error &&
          other.appNotification == appNotification &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      appNotification.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'AppNotificationState(error: $error, appNotification: $appNotification)';
}

// END GENERATED
