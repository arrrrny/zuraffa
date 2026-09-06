// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/barcode_spark_repository.dart';
import '../../domain/usecases/barcode_spark/get_barcode_spark_usecase.dart';

void registerGetBarcodeSparkUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetBarcodeSparkUseCase>(
    () => GetBarcodeSparkUseCase(getIt<BarcodeSparkRepository>()),
  );
}

// END GENERATED
