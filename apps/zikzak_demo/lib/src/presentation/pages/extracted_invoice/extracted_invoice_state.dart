// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/extracted_invoice/extracted_invoice.dart';

class ExtractedInvoiceState {
  const ExtractedInvoiceState({
    this.error,
    this.extractedInvoice,
    this.isGetting = false,
    this.isUpdating = false,
    this.isToggling = false,
  });

  /// The current error, if any
  final AppFailure? error;

  /// The single ExtractedInvoice entity
  final ExtractedInvoice? extractedInvoice;

  /// Whether get is in progress
  final bool isGetting;

  /// Whether update is in progress
  final bool isUpdating;

  /// Whether toggle is in progress
  final bool isToggling;

  ExtractedInvoiceState copyWith({
    AppFailure? error,
    ExtractedInvoice? extractedInvoice,
    bool? isGetting,
    bool? isUpdating,
    bool? isToggling,
  }) => ExtractedInvoiceState(
    error: error ?? this.error,
    extractedInvoice: extractedInvoice ?? this.extractedInvoice,
    isGetting: isGetting ?? this.isGetting,
    isUpdating: isUpdating ?? this.isUpdating,
    isToggling: isToggling ?? this.isToggling,
  );

  bool get isLoading => isGetting || isUpdating || isToggling;

  bool get hasError => error != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtractedInvoiceState &&
          other.error == error &&
          other.extractedInvoice == extractedInvoice &&
          other.isGetting == isGetting &&
          other.isUpdating == isUpdating &&
          other.isToggling == isToggling;

  @override
  int get hashCode =>
      error.hashCode +
      extractedInvoice.hashCode +
      isGetting.hashCode +
      isUpdating.hashCode +
      isToggling.hashCode;

  @override
  String toString() =>
      'ExtractedInvoiceState(error: $error, extractedInvoice: $extractedInvoice)';
}

// END GENERATED
