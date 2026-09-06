// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/barcode_listing/barcode_listing.dart';

abstract class BarcodeListingDataSource with Loggable, FailureHandler {
  Future<BarcodeListing> get(QueryParams<BarcodeListing> params);
  Future<BarcodeListing> update(
    UpdateParams<String, BarcodeListingPatch> params,
  );
  Future<BarcodeListing> toggle(
    ToggleParams<String, Field<BarcodeListing, dynamic>> params,
  );
}

// END GENERATED
