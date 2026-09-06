// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/price_alert/price_alert.dart';

class PriceAlertState {
  const PriceAlertState({
    this.error,
    this.priceAlert,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single PriceAlert entity
  final PriceAlert? priceAlert;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  PriceAlertState copyWith({
    AppFailure? error,
    PriceAlert? priceAlert,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => PriceAlertState(
    error: error ?? this.error,
    priceAlert: priceAlert ?? this.priceAlert,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PriceAlertState &&
          other.error == error &&
          other.priceAlert == priceAlert &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      priceAlert.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'PriceAlertState(error: $error, priceAlert: $priceAlert)';
}

// END GENERATED
