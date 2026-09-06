// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/listing_offer_repository.dart';
import '../../domain/usecases/listing_offer/toggle_listing_offer_usecase.dart';

void registerToggleListingOfferUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleListingOfferUseCase>(
    () => ToggleListingOfferUseCase(getIt<ListingOfferRepository>()),
  );
}

// END GENERATED
