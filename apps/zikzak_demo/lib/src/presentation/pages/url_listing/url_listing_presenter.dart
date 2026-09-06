// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/url_listing/url_listing.dart';
import '../../../domain/usecases/url_listing/get_url_listing_usecase.dart';
import '../../../domain/usecases/url_listing/toggle_url_listing_usecase.dart';
import '../../../domain/usecases/url_listing/update_url_listing_usecase.dart';

class UrlListingPresenter extends Presenter {
  UrlListingPresenter() {
    _getUrlListing = registerUseCase(getIt<GetUrlListingUseCase>());
    _updateUrlListing = registerUseCase(getIt<UpdateUrlListingUseCase>());
    _toggleUrlListing = registerUseCase(getIt<ToggleUrlListingUseCase>());
  }

  late final GetUrlListingUseCase _getUrlListing;

  late final UpdateUrlListingUseCase _updateUrlListing;

  late final ToggleUrlListingUseCase _toggleUrlListing;

  Future<Result<UrlListing, AppFailure>> getUrlListing(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getUrlListing.call(
      QueryParams<UrlListing>(filter: Eq(UrlListingFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<UrlListing, AppFailure>> updateUrlListing(
    String id,
    UrlListingPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateUrlListing.call(
      UpdateParams<String, UrlListingPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<UrlListing, AppFailure>> toggleUrlListing(
    String id,
    Field<UrlListing, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleUrlListing.call(
      ToggleParams<String, Field<UrlListing, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
