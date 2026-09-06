// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/listing_offer/listing_offer.dart';
import 'listing_offer_datasource.dart';

class ListingOfferRemoteDataSource
    with Loggable, FailureHandler
    implements ListingOfferDataSource {
  @override
  Future<ListingOffer> get(QueryParams<ListingOffer> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<ListingOffer> update(
    UpdateParams<String, ListingOfferPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<ListingOffer> toggle(
    ToggleParams<String, Field<ListingOffer, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
