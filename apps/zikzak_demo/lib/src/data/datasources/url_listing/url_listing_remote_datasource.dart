// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/url_listing/url_listing.dart';
import 'url_listing_datasource.dart';

class UrlListingRemoteDataSource
    with Loggable, FailureHandler
    implements UrlListingDataSource {
  @override
  Future<UrlListing> get(QueryParams<UrlListing> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<UrlListing> update(
    UpdateParams<String, UrlListingPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<UrlListing> toggle(
    ToggleParams<String, Field<UrlListing, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
