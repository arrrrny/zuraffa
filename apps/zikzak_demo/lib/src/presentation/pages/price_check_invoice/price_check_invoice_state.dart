// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/price_check_invoice/price_check_invoice.dart';

class PriceCheckInvoiceState {
  const PriceCheckInvoiceState({
    this.error,
    this.priceCheckInvoice,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single PriceCheckInvoice entity
  final PriceCheckInvoice? priceCheckInvoice;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  PriceCheckInvoiceState copyWith({
    AppFailure? error,
    PriceCheckInvoice? priceCheckInvoice,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => PriceCheckInvoiceState(
    error: error ?? this.error,
    priceCheckInvoice: priceCheckInvoice ?? this.priceCheckInvoice,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PriceCheckInvoiceState &&
          other.error == error &&
          other.priceCheckInvoice == priceCheckInvoice &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      priceCheckInvoice.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'PriceCheckInvoiceState(error: $error, priceCheckInvoice: $priceCheckInvoice)';
}

// END GENERATED
