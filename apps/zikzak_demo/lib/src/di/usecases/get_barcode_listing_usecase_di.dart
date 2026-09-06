// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/barcode_listing_repository.dart';
import '../../domain/usecases/barcode_listing/get_barcode_listing_usecase.dart';

void registerGetBarcodeListingUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetBarcodeListingUseCase>(
    () => GetBarcodeListingUseCase(getIt<BarcodeListingRepository>()),
  );
}

// END GENERATED
