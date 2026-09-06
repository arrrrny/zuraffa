// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/url_listing/url_listing.dart';

abstract class UrlListingDataSource with Loggable, FailureHandler {
  Future<UrlListing> get(QueryParams<UrlListing> params);
  Future<UrlListing> update(UpdateParams<String, UrlListingPatch> params);
  Future<UrlListing> toggle(
    ToggleParams<String, Field<UrlListing, dynamic>> params,
  );
}

// END GENERATED
