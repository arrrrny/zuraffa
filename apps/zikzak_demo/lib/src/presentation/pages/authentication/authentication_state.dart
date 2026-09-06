// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/authentication/authentication.dart';

class AuthenticationState {
  const AuthenticationState({
    this.error,
    this.authentication,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single Authentication entity
  final Authentication? authentication;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  AuthenticationState copyWith({
    AppFailure? error,
    Authentication? authentication,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => AuthenticationState(
    error: error ?? this.error,
    authentication: authentication ?? this.authentication,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthenticationState &&
          other.error == error &&
          other.authentication == authentication &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      authentication.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'AuthenticationState(error: $error, authentication: $authentication)';
}

// END GENERATED
