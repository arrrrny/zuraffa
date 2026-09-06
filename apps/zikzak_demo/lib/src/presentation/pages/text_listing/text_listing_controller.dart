// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/text_listing/text_listing.dart';
import 'text_listing_presenter.dart';

class TextListingController extends Controller {
  TextListingController(this._presenter);

  final TextListingPresenter _presenter;

  Future<void> getTextListing(String id, [CancelToken? cancelToken]) async {
    final result = await _presenter.getTextListing(id, cancelToken);
    result.fold((entity) {}, (failure) {});
  }

  Future<void> updateTextListing(
    String id,
    TextListingPatch data, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.updateTextListing(id, data, cancelToken);
    result.fold((updated) {}, (failure) {});
  }

  Future<void> toggleTextListing(
    String id,
    Field<TextListing, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    final result = await _presenter.toggleTextListing(
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
