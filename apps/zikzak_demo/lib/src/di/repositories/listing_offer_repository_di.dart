// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/listing_offer/listing_offer_remote_datasource.dart';
import '../../data/repositories/data_listing_offer_repository.dart';
import '../../domain/repositories/listing_offer_repository.dart';

void registerListingOfferRepository(GetIt getIt) {
  getIt.registerLazySingleton<ListingOfferRepository>(
    () => DataListingOfferRepository(getIt<ListingOfferRemoteDataSource>()),
  );
}

// END GENERATED
