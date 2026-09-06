// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/text_listing_repository.dart';
import '../../domain/usecases/text_listing/toggle_text_listing_usecase.dart';

void registerToggleTextListingUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleTextListingUseCase>(
    () => ToggleTextListingUseCase(getIt<TextListingRepository>()),
  );
}

// END GENERATED
