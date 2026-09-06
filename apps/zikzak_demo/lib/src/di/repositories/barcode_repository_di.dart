// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/barcode/barcode_remote_datasource.dart';
import '../../data/repositories/data_barcode_repository.dart';
import '../../domain/repositories/barcode_repository.dart';

void registerBarcodeRepository(GetIt getIt) {
  getIt.registerLazySingleton<BarcodeRepository>(
    () => DataBarcodeRepository(getIt<BarcodeRemoteDataSource>()),
  );
}

// END GENERATED
