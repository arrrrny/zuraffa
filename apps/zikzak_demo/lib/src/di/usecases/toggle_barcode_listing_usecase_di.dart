// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/barcode_listing_repository.dart';
import '../../domain/usecases/barcode_listing/toggle_barcode_listing_usecase.dart';

void registerToggleBarcodeListingUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleBarcodeListingUseCase>(
    () => ToggleBarcodeListingUseCase(getIt<BarcodeListingRepository>()),
  );
}

// END GENERATED
