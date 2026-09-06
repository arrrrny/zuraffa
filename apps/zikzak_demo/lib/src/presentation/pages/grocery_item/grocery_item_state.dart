// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/grocery_item/grocery_item.dart';

class GroceryItemState {
  const GroceryItemState({
    this.error,
    this.groceryItem,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single GroceryItem entity
  final GroceryItem? groceryItem;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  GroceryItemState copyWith({
    AppFailure? error,
    GroceryItem? groceryItem,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => GroceryItemState(
    error: error ?? this.error,
    groceryItem: groceryItem ?? this.groceryItem,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroceryItemState &&
          other.error == error &&
          other.groceryItem == groceryItem &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      groceryItem.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'GroceryItemState(error: $error, groceryItem: $groceryItem)';
}

// END GENERATED
