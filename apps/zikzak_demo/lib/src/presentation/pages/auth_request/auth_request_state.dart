// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/auth_request/auth_request.dart';

class AuthRequestState {
  const AuthRequestState({
    this.error,
    this.authRequest,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single AuthRequest entity
  final AuthRequest? authRequest;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  AuthRequestState copyWith({
    AppFailure? error,
    AuthRequest? authRequest,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => AuthRequestState(
    error: error ?? this.error,
    authRequest: authRequest ?? this.authRequest,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthRequestState &&
          other.error == error &&
          other.authRequest == authRequest &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      authRequest.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'AuthRequestState(error: $error, authRequest: $authRequest)';
}

// END GENERATED
