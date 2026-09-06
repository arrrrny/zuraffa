// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/grocery_sub_variety/grocery_sub_variety.dart';

class GrocerySubVarietyState {
  const GrocerySubVarietyState({
    this.error,
    this.grocerySubVariety,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single GrocerySubVariety entity
  final GrocerySubVariety? grocerySubVariety;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  GrocerySubVarietyState copyWith({
    AppFailure? error,
    GrocerySubVariety? grocerySubVariety,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => GrocerySubVarietyState(
    error: error ?? this.error,
    grocerySubVariety: grocerySubVariety ?? this.grocerySubVariety,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GrocerySubVarietyState &&
          other.error == error &&
          other.grocerySubVariety == grocerySubVariety &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      grocerySubVariety.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'GrocerySubVarietyState(error: $error, grocerySubVariety: $grocerySubVariety)';
}

// END GENERATED
