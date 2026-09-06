// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/barcode_spark_repository.dart';
import '../../domain/usecases/barcode_spark/update_barcode_spark_usecase.dart';

void registerUpdateBarcodeSparkUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateBarcodeSparkUseCase>(
    () => UpdateBarcodeSparkUseCase(getIt<BarcodeSparkRepository>()),
  );
}

// END GENERATED
