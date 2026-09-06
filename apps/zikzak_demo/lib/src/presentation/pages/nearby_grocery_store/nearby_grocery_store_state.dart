// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/nearby_grocery_store/nearby_grocery_store.dart';

class NearbyGroceryStoreState {
  const NearbyGroceryStoreState({
    this.error,
    this.nearbyGroceryStore,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single NearbyGroceryStore entity
  final NearbyGroceryStore? nearbyGroceryStore;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  NearbyGroceryStoreState copyWith({
    AppFailure? error,
    NearbyGroceryStore? nearbyGroceryStore,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => NearbyGroceryStoreState(
    error: error ?? this.error,
    nearbyGroceryStore: nearbyGroceryStore ?? this.nearbyGroceryStore,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NearbyGroceryStoreState &&
          other.error == error &&
          other.nearbyGroceryStore == nearbyGroceryStore &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      nearbyGroceryStore.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'NearbyGroceryStoreState(error: $error, nearbyGroceryStore: $nearbyGroceryStore)';
}

// END GENERATED
