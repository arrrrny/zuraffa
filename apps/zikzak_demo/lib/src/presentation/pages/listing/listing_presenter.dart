// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/listing/listing.dart';
import '../../../domain/usecases/listing/get_listing_usecase.dart';
import '../../../domain/usecases/listing/toggle_listing_usecase.dart';
import '../../../domain/usecases/listing/update_listing_usecase.dart';

class ListingPresenter extends Presenter {
  ListingPresenter() {
    _getListing = registerUseCase(getIt<GetListingUseCase>());
    _updateListing = registerUseCase(getIt<UpdateListingUseCase>());
    _toggleListing = registerUseCase(getIt<ToggleListingUseCase>());
  }

  late final GetListingUseCase _getListing;

  late final UpdateListingUseCase _updateListing;

  late final ToggleListingUseCase _toggleListing;

  Future<Result<Listing, AppFailure>> getListing(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getListing.call(
      QueryParams<Listing>(filter: Eq(ListingFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<Listing, AppFailure>> updateListing(
    String id,
    ListingPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateListing.call(
      UpdateParams<String, ListingPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<Listing, AppFailure>> toggleListing(
    String id,
    Field<Listing, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleListing.call(
      ToggleParams<String, Field<Listing, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
