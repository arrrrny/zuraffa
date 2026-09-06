// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/barcode_spark_repository.dart';
import '../../domain/usecases/barcode_spark/toggle_barcode_spark_usecase.dart';

void registerToggleBarcodeSparkUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleBarcodeSparkUseCase>(
    () => ToggleBarcodeSparkUseCase(getIt<BarcodeSparkRepository>()),
  );
}

// END GENERATED
