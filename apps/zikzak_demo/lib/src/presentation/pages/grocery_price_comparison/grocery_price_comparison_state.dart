// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/grocery_price_comparison/grocery_price_comparison.dart';

class GroceryPriceComparisonState {
  const GroceryPriceComparisonState({
    this.error,
    this.groceryPriceComparison,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single GroceryPriceComparison entity
  final GroceryPriceComparison? groceryPriceComparison;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  GroceryPriceComparisonState copyWith({
    AppFailure? error,
    GroceryPriceComparison? groceryPriceComparison,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => GroceryPriceComparisonState(
    error: error ?? this.error,
    groceryPriceComparison:
        groceryPriceComparison ?? this.groceryPriceComparison,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroceryPriceComparisonState &&
          other.error == error &&
          other.groceryPriceComparison == groceryPriceComparison &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      groceryPriceComparison.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'GroceryPriceComparisonState(error: $error, groceryPriceComparison: $groceryPriceComparison)';
}

// END GENERATED
