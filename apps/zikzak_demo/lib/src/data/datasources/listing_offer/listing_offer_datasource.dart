// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/listing_offer/listing_offer.dart';

abstract class ListingOfferDataSource with Loggable, FailureHandler {
  Future<ListingOffer> get(QueryParams<ListingOffer> params);
  Future<ListingOffer> update(UpdateParams<String, ListingOfferPatch> params);
  Future<ListingOffer> toggle(
    ToggleParams<String, Field<ListingOffer, dynamic>> params,
  );
}

// END GENERATED
