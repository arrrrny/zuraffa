// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/listing_offer/listing_offer.dart';

class ListingOfferState {
  const ListingOfferState({
    this.error,
    this.listingOffer,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single ListingOffer entity
  final ListingOffer? listingOffer;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  ListingOfferState copyWith({
    AppFailure? error,
    ListingOffer? listingOffer,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => ListingOfferState(
    error: error ?? this.error,
    listingOffer: listingOffer ?? this.listingOffer,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListingOfferState &&
          other.error == error &&
          other.listingOffer == listingOffer &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      listingOffer.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'ListingOfferState(error: $error, listingOffer: $listingOffer)';
}

// END GENERATED
