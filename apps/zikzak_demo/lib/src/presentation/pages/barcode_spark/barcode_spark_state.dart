// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/barcode_spark/barcode_spark.dart';

class BarcodeSparkState {
  const BarcodeSparkState({
    this.error,
    this.barcodeSpark,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single BarcodeSpark entity
  final BarcodeSpark? barcodeSpark;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  BarcodeSparkState copyWith({
    AppFailure? error,
    BarcodeSpark? barcodeSpark,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => BarcodeSparkState(
    error: error ?? this.error,
    barcodeSpark: barcodeSpark ?? this.barcodeSpark,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BarcodeSparkState &&
          other.error == error &&
          other.barcodeSpark == barcodeSpark &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      barcodeSpark.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'BarcodeSparkState(error: $error, barcodeSpark: $barcodeSpark)';
}

// END GENERATED
