import 'package:zuraffa/zuraffa.dart';

import '../../../domain/usecases/engagement_usecases.dart';

/// Controller for the barcode listing page.
///
/// Engagement capture is automated by the EngagementHook registered in
/// main() — controllers carry no manual engagement call sites (C5).
class BarcodeListingController {
  BarcodeListingController(this._scanBarcode, this._searchProducts);

  final CreateBarcodeScanUseCase _scanBarcode;
  final SearchProductsUseCase _searchProducts;

  /// Scans a barcode and returns the raw barcode number on success.
  Future<Result<String, AppFailure>> scanBarcode(String barcode) =>
      _scanBarcode(barcode);

  /// Runs a product search and returns matching catalogue entries.
  Future<Result<List<String>, AppFailure>> search(String query) =>
      _searchProducts(query);
}
