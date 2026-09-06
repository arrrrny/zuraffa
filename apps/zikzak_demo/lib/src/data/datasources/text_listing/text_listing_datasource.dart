// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/text_listing/text_listing.dart';

abstract class TextListingDataSource with Loggable, FailureHandler {
  Future<TextListing> get(QueryParams<TextListing> params);
  Future<TextListing> update(UpdateParams<String, TextListingPatch> params);
  Future<TextListing> toggle(
    ToggleParams<String, Field<TextListing, dynamic>> params,
  );
}

// END GENERATED
