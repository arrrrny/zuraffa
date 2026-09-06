// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/grocery_product/grocery_product.dart';

class GroceryProductState {
  const GroceryProductState({
    this.error,
    this.groceryProduct,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single GroceryProduct entity
  final GroceryProduct? groceryProduct;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  GroceryProductState copyWith({
    AppFailure? error,
    GroceryProduct? groceryProduct,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => GroceryProductState(
    error: error ?? this.error,
    groceryProduct: groceryProduct ?? this.groceryProduct,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroceryProductState &&
          other.error == error &&
          other.groceryProduct == groceryProduct &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      groceryProduct.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'GroceryProductState(error: $error, groceryProduct: $groceryProduct)';
}

// END GENERATED
