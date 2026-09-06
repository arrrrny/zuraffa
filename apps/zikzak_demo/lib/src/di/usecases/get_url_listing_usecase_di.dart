// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/url_listing_repository.dart';
import '../../domain/usecases/url_listing/get_url_listing_usecase.dart';

void registerGetUrlListingUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetUrlListingUseCase>(
    () => GetUrlListingUseCase(getIt<UrlListingRepository>()),
  );
}

// END GENERATED
