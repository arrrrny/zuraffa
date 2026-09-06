// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/listing_repository.dart';
import '../../domain/usecases/listing/update_listing_usecase.dart';

void registerUpdateListingUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateListingUseCase>(
    () => UpdateListingUseCase(getIt<ListingRepository>()),
  );
}

// END GENERATED
