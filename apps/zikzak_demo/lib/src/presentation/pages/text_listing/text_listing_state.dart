// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/text_listing/text_listing.dart';

class TextListingState {
  const TextListingState({
    this.error,
    this.textListing,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single TextListing entity
  final TextListing? textListing;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  TextListingState copyWith({
    AppFailure? error,
    TextListing? textListing,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => TextListingState(
    error: error ?? this.error,
    textListing: textListing ?? this.textListing,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextListingState &&
          other.error == error &&
          other.textListing == textListing &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      textListing.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'TextListingState(error: $error, textListing: $textListing)';
}

// END GENERATED
