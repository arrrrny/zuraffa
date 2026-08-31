import 'dart:async';

import 'package:zuraffa/zuraffa.dart';

import '../../../domain/usecases/engagement_usecases.dart';
import '../../../telemetry/create_telemetry_event_use_case.dart';

/// Controller for the barcode listing page (RED — contains manual calls).
class BarcodeListingController {
  BarcodeListingController(
    this._scanBarcode,
    this._searchProducts,
    this._telemetry,
  );

  final CreateBarcodeScanUseCase _scanBarcode;
  final SearchProductsUseCase _searchProducts;
  final CreateTelemetryEventUseCase _telemetry;

  /// Scans a barcode and returns the raw barcode number on success.
  Future<Result<String, AppFailure>> scanBarcode(String barcode) async {
    final result = await _scanBarcode(barcode);
    result.fold(
      (_) => _trackBarcodeScanned(barcode),
      (_) {},
    );
    return result;
  }

  /// Runs a product search and returns matching catalogue entries.
  Future<Result<List<String>, AppFailure>> search(String query) async {
    final result = await _searchProducts(query);
    result.fold(
      (_) => _trackSearchQuery(query),
      (_) {},
    );
    return result;
  }

  void _trackBarcodeScanned(String barcode) {
    unawaited(
      _telemetry.call(<String, dynamic>{'event': 'BARCODE_SCAN', 'payload': barcode}),
    );
  }

  void _trackSearchQuery(String query) {
    unawaited(
      _telemetry.call(<String, dynamic>{'event': 'SEARCH_TERM', 'payload': query}),
    );
  }
}
