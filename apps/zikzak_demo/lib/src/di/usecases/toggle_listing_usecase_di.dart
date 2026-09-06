// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/listing_repository.dart';
import '../../domain/usecases/listing/toggle_listing_usecase.dart';

void registerToggleListingUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleListingUseCase>(
    () => ToggleListingUseCase(getIt<ListingRepository>()),
  );
}

// END GENERATED
