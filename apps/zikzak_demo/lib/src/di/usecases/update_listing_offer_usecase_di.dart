// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/listing_offer_repository.dart';
import '../../domain/usecases/listing_offer/update_listing_offer_usecase.dart';

void registerUpdateListingOfferUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateListingOfferUseCase>(
    () => UpdateListingOfferUseCase(getIt<ListingOfferRepository>()),
  );
}

// END GENERATED
