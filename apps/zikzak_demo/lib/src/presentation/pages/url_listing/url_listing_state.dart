// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/url_listing/url_listing.dart';

class UrlListingState {
  const UrlListingState({
    this.error,
    this.urlListing,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single UrlListing entity
  final UrlListing? urlListing;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  UrlListingState copyWith({
    AppFailure? error,
    UrlListing? urlListing,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => UrlListingState(
    error: error ?? this.error,
    urlListing: urlListing ?? this.urlListing,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UrlListingState &&
          other.error == error &&
          other.urlListing == urlListing &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      urlListing.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'UrlListingState(error: $error, urlListing: $urlListing)';
}

// END GENERATED
