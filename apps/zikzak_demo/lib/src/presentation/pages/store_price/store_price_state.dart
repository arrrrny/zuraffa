// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/store_price/store_price.dart';

class StorePriceState {
  const StorePriceState({
    this.error,
    this.storePrice,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single StorePrice entity
  final StorePrice? storePrice;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  StorePriceState copyWith({
    AppFailure? error,
    StorePrice? storePrice,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => StorePriceState(
    error: error ?? this.error,
    storePrice: storePrice ?? this.storePrice,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StorePriceState &&
          other.error == error &&
          other.storePrice == storePrice &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      storePrice.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'StorePriceState(error: $error, storePrice: $storePrice)';
}

// END GENERATED
