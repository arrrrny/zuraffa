// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/grocery_price_result/grocery_price_result.dart';

class GroceryPriceResultState {
  const GroceryPriceResultState({
    this.error,
    this.groceryPriceResult,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single GroceryPriceResult entity
  final GroceryPriceResult? groceryPriceResult;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  GroceryPriceResultState copyWith({
    AppFailure? error,
    GroceryPriceResult? groceryPriceResult,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => GroceryPriceResultState(
    error: error ?? this.error,
    groceryPriceResult: groceryPriceResult ?? this.groceryPriceResult,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroceryPriceResultState &&
          other.error == error &&
          other.groceryPriceResult == groceryPriceResult &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      groceryPriceResult.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'GroceryPriceResultState(error: $error, groceryPriceResult: $groceryPriceResult)';
}

// END GENERATED
