// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/text_listing/text_listing.dart';
import '../../../domain/usecases/text_listing/get_text_listing_usecase.dart';
import '../../../domain/usecases/text_listing/toggle_text_listing_usecase.dart';
import '../../../domain/usecases/text_listing/update_text_listing_usecase.dart';

class TextListingPresenter extends Presenter {
  TextListingPresenter() {
    _getTextListing = registerUseCase(getIt<GetTextListingUseCase>());
    _updateTextListing = registerUseCase(getIt<UpdateTextListingUseCase>());
    _toggleTextListing = registerUseCase(getIt<ToggleTextListingUseCase>());
  }

  late final GetTextListingUseCase _getTextListing;

  late final UpdateTextListingUseCase _updateTextListing;

  late final ToggleTextListingUseCase _toggleTextListing;

  Future<Result<TextListing, AppFailure>> getTextListing(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getTextListing.call(
      QueryParams<TextListing>(filter: Eq(TextListingFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<TextListing, AppFailure>> updateTextListing(
    String id,
    TextListingPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateTextListing.call(
      UpdateParams<String, TextListingPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<TextListing, AppFailure>> toggleTextListing(
    String id,
    Field<TextListing, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleTextListing.call(
      ToggleParams<String, Field<TextListing, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
