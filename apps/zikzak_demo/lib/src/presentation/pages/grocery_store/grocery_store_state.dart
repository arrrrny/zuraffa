// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/grocery_store/grocery_store.dart';

class GroceryStoreState {
  const GroceryStoreState({
    this.error,
    this.groceryStore,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single GroceryStore entity
  final GroceryStore? groceryStore;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  GroceryStoreState copyWith({
    AppFailure? error,
    GroceryStore? groceryStore,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => GroceryStoreState(
    error: error ?? this.error,
    groceryStore: groceryStore ?? this.groceryStore,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroceryStoreState &&
          other.error == error &&
          other.groceryStore == groceryStore &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      groceryStore.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'GroceryStoreState(error: $error, groceryStore: $groceryStore)';
}

// END GENERATED
