// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/barcode_listing_repository.dart';
import '../../domain/usecases/barcode_listing/update_barcode_listing_usecase.dart';

void registerUpdateBarcodeListingUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateBarcodeListingUseCase>(
    () => UpdateBarcodeListingUseCase(getIt<BarcodeListingRepository>()),
  );
}

// END GENERATED
