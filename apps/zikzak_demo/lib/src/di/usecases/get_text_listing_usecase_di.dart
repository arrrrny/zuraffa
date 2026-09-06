// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/text_listing_repository.dart';
import '../../domain/usecases/text_listing/get_text_listing_usecase.dart';

void registerGetTextListingUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetTextListingUseCase>(
    () => GetTextListingUseCase(getIt<TextListingRepository>()),
  );
}

// END GENERATED
