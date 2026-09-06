// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/barcode_listing/barcode_listing.dart';
import 'barcode_listing_datasource.dart';

class BarcodeListingRemoteDataSource
    with Loggable, FailureHandler
    implements BarcodeListingDataSource {
  @override
  Future<BarcodeListing> get(QueryParams<BarcodeListing> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<BarcodeListing> update(
    UpdateParams<String, BarcodeListingPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<BarcodeListing> toggle(
    ToggleParams<String, Field<BarcodeListing, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
