// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/listing_offer/listing_offer.dart';
import 'listing_offer_presenter.dart';

class ListingOfferController extends Controller {
  ListingOfferController(this._presenter);

  final ListingOfferPresenter _presenter;

  Future<void> getListingOffer(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getListingOffer(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateListingOffer(
    String id,
    ListingOfferPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateListingOffer(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleListingOffer(
    String id,
    Field<ListingOffer, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleListingOffer(
      id,
      field,
      toggleValue,
      cancelToken,
    );
    result.fold((toggled) {}, (failure) {});
  }

  @override
  void onDisposed() {
    _presenter.dispose();
    super.onDisposed();
  }
}

// END GENERATED
