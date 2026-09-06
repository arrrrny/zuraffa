// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/barcode_listing/barcode_listing.dart';
import '../../../domain/usecases/barcode_listing/get_barcode_listing_usecase.dart';
import '../../../domain/usecases/barcode_listing/toggle_barcode_listing_usecase.dart';
import '../../../domain/usecases/barcode_listing/update_barcode_listing_usecase.dart';

class BarcodeListingPresenter extends Presenter {
  BarcodeListingPresenter() {
    _getBarcodeListing = registerUseCase(getIt<GetBarcodeListingUseCase>());
    _updateBarcodeListing = registerUseCase(
      getIt<UpdateBarcodeListingUseCase>(),
    );
    _toggleBarcodeListing = registerUseCase(
      getIt<ToggleBarcodeListingUseCase>(),
    );
  }

  late final GetBarcodeListingUseCase _getBarcodeListing;

  late final UpdateBarcodeListingUseCase _updateBarcodeListing;

  late final ToggleBarcodeListingUseCase _toggleBarcodeListing;

  Future<Result<BarcodeListing, AppFailure>> getBarcodeListing(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getBarcodeListing.call(
      QueryParams<BarcodeListing>(filter: Eq(BarcodeListingFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<BarcodeListing, AppFailure>> updateBarcodeListing(
    String id,
    BarcodeListingPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateBarcodeListing.call(
      UpdateParams<String, BarcodeListingPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<BarcodeListing, AppFailure>> toggleBarcodeListing(
    String id,
    Field<BarcodeListing, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleBarcodeListing.call(
      ToggleParams<String, Field<BarcodeListing, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
