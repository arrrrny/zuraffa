// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/customer_address/customer_address.dart';

class CustomerAddressState {
  const CustomerAddressState({
    this.error,
    this.customerAddress,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single CustomerAddress entity
  final CustomerAddress? customerAddress;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  CustomerAddressState copyWith({
    AppFailure? error,
    CustomerAddress? customerAddress,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => CustomerAddressState(
    error: error ?? this.error,
    customerAddress: customerAddress ?? this.customerAddress,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerAddressState &&
          other.error == error &&
          other.customerAddress == customerAddress &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      customerAddress.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'CustomerAddressState(error: $error, customerAddress: $customerAddress)';
}

// END GENERATED
