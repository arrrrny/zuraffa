// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/customer/customer.dart';

class CustomerState {
  const CustomerState({
    this.error,
    this.customer,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single Customer entity
  final Customer? customer;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  CustomerState copyWith({
    AppFailure? error,
    Customer? customer,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => CustomerState(
    error: error ?? this.error,
    customer: customer ?? this.customer,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerState &&
          other.error == error &&
          other.customer == customer &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      customer.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() => 'CustomerState(error: $error, customer: $customer)';
}

// END GENERATED
