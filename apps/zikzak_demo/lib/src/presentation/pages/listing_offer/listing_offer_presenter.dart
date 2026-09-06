// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/listing_offer/listing_offer.dart';
import '../../../domain/usecases/listing_offer/get_listing_offer_usecase.dart';
import '../../../domain/usecases/listing_offer/toggle_listing_offer_usecase.dart';
import '../../../domain/usecases/listing_offer/update_listing_offer_usecase.dart';

class ListingOfferPresenter extends Presenter {
  ListingOfferPresenter() {
    _getListingOffer = registerUseCase(getIt<GetListingOfferUseCase>());
    _updateListingOffer = registerUseCase(getIt<UpdateListingOfferUseCase>());
    _toggleListingOffer = registerUseCase(getIt<ToggleListingOfferUseCase>());
  }

  late final GetListingOfferUseCase _getListingOffer;

  late final UpdateListingOfferUseCase _updateListingOffer;

  late final ToggleListingOfferUseCase _toggleListingOffer;

  Future<Result<ListingOffer, AppFailure>> getListingOffer(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getListingOffer.call(
      QueryParams<ListingOffer>(filter: Eq(ListingOfferFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<ListingOffer, AppFailure>> updateListingOffer(
    String id,
    ListingOfferPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateListingOffer.call(
      UpdateParams<String, ListingOfferPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<ListingOffer, AppFailure>> toggleListingOffer(
    String id,
    Field<ListingOffer, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleListingOffer.call(
      ToggleParams<String, Field<ListingOffer, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
