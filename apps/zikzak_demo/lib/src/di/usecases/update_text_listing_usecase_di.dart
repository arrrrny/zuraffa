// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/text_listing_repository.dart';
import '../../domain/usecases/text_listing/update_text_listing_usecase.dart';

void registerUpdateTextListingUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateTextListingUseCase>(
    () => UpdateTextListingUseCase(getIt<TextListingRepository>()),
  );
}

// END GENERATED
