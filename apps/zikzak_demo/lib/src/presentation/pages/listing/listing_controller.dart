// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/listing/listing.dart';
import 'listing_presenter.dart';

class ListingController extends Controller {
  ListingController(this._presenter);

  final ListingPresenter _presenter;

  Future<void> getListing(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getListing(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateListing(
    String id,
    ListingPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateListing(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleListing(
    String id,
    Field<Listing, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleListing(
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
