// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/barcode/barcode.dart';

class BarcodeState {
  const BarcodeState({
    this.error,
    this.barcode,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single Barcode entity
  final Barcode? barcode;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  BarcodeState copyWith({
    AppFailure? error,
    Barcode? barcode,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => BarcodeState(
    error: error ?? this.error,
    barcode: barcode ?? this.barcode,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BarcodeState &&
          other.error == error &&
          other.barcode == barcode &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      barcode.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() => 'BarcodeState(error: $error, barcode: $barcode)';
}

// END GENERATED
