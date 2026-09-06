// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/listing_repository.dart';
import '../../domain/usecases/listing/get_listing_usecase.dart';

void registerGetListingUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetListingUseCase>(
    () => GetListingUseCase(getIt<ListingRepository>()),
  );
}

// END GENERATED
