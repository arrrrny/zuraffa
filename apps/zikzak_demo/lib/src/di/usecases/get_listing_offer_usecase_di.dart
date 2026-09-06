// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/listing_offer_repository.dart';
import '../../domain/usecases/listing_offer/get_listing_offer_usecase.dart';

void registerGetListingOfferUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetListingOfferUseCase>(
    () => GetListingOfferUseCase(getIt<ListingOfferRepository>()),
  );
}

// END GENERATED
