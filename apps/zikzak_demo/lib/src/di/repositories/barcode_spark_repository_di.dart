// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/barcode_spark/barcode_spark_remote_datasource.dart';
import '../../data/repositories/data_barcode_spark_repository.dart';
import '../../domain/repositories/barcode_spark_repository.dart';

void registerBarcodeSparkRepository(GetIt getIt) {
  getIt.registerLazySingleton<BarcodeSparkRepository>(
    () => DataBarcodeSparkRepository(getIt<BarcodeSparkRemoteDataSource>()),
  );
}

// END GENERATED
