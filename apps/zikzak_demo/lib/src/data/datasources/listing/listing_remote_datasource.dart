// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/listing/listing.dart';
import 'listing_datasource.dart';

class ListingRemoteDataSource
    with Loggable, FailureHandler
    implements ListingDataSource {
  @override
  Future<Listing> get(QueryParams<Listing> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<Listing> update(UpdateParams<String, ListingPatch> params) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<Listing> toggle(
    ToggleParams<String, Field<Listing, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
