// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/connected_account/connected_account.dart';

class ConnectedAccountState {
  const ConnectedAccountState({
    this.error,
    this.connectedAccount,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single ConnectedAccount entity
  final ConnectedAccount? connectedAccount;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  ConnectedAccountState copyWith({
    AppFailure? error,
    ConnectedAccount? connectedAccount,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => ConnectedAccountState(
    error: error ?? this.error,
    connectedAccount: connectedAccount ?? this.connectedAccount,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectedAccountState &&
          other.error == error &&
          other.connectedAccount == connectedAccount &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      connectedAccount.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'ConnectedAccountState(error: $error, connectedAccount: $connectedAccount)';
}

// END GENERATED
