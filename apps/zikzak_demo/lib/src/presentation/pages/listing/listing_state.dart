// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/listing/listing.dart';

class ListingState {
  const ListingState({
    this.error,
    this.listing,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single Listing entity
  final Listing? listing;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  ListingState copyWith({
    AppFailure? error,
    Listing? listing,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => ListingState(
    error: error ?? this.error,
    listing: listing ?? this.listing,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListingState &&
          other.error == error &&
          other.listing == listing &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      listing.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() => 'ListingState(error: $error, listing: $listing)';
}

// END GENERATED
