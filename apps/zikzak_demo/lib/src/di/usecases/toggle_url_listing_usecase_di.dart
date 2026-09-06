// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/url_listing_repository.dart';
import '../../domain/usecases/url_listing/toggle_url_listing_usecase.dart';

void registerToggleUrlListingUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleUrlListingUseCase>(
    () => ToggleUrlListingUseCase(getIt<UrlListingRepository>()),
  );
}

// END GENERATED
