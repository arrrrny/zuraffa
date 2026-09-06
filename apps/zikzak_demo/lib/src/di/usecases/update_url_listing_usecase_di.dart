// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/url_listing_repository.dart';
import '../../domain/usecases/url_listing/update_url_listing_usecase.dart';

void registerUpdateUrlListingUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateUrlListingUseCase>(
    () => UpdateUrlListingUseCase(getIt<UrlListingRepository>()),
  );
}

// END GENERATED
