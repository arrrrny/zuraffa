// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/text_listing/text_listing.dart';
import 'text_listing_datasource.dart';

class TextListingRemoteDataSource
    with Loggable, FailureHandler
    implements TextListingDataSource {
  @override
  Future<TextListing> get(QueryParams<TextListing> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<TextListing> update(
    UpdateParams<String, TextListingPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<TextListing> toggle(
    ToggleParams<String, Field<TextListing, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
