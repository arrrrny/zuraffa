// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/listing/listing.dart';

abstract class ListingDataSource with Loggable, FailureHandler {
  Future<Listing> get(QueryParams<Listing> params);
  Future<Listing> update(UpdateParams<String, ListingPatch> params);
  Future<Listing> toggle(ToggleParams<String, Field<Listing, dynamic>> params);
}

// END GENERATED
