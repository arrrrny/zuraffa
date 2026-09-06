// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/barcode_listing/barcode_listing_remote_datasource.dart';
import '../../data/repositories/data_barcode_listing_repository.dart';
import '../../domain/repositories/barcode_listing_repository.dart';

void registerBarcodeListingRepository(GetIt getIt) {
  getIt.registerLazySingleton<BarcodeListingRepository>(
    () => DataBarcodeListingRepository(getIt<BarcodeListingRemoteDataSource>()),
  );
}

// END GENERATED
