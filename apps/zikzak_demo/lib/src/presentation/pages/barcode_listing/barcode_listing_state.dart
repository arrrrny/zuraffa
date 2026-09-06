// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/barcode_listing/barcode_listing.dart';

class BarcodeListingState {
  const BarcodeListingState({
    this.error,
    this.barcodeListing,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single BarcodeListing entity
  final BarcodeListing? barcodeListing;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  BarcodeListingState copyWith({
    AppFailure? error,
    BarcodeListing? barcodeListing,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => BarcodeListingState(
    error: error ?? this.error,
    barcodeListing: barcodeListing ?? this.barcodeListing,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BarcodeListingState &&
          other.error == error &&
          other.barcodeListing == barcodeListing &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      barcodeListing.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'BarcodeListingState(error: $error, barcodeListing: $barcodeListing)';
}

// END GENERATED
