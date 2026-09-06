// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/barcode_repository.dart';
import '../../domain/usecases/barcode/update_barcode_usecase.dart';

void registerUpdateBarcodeUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateBarcodeUseCase>(
    () => UpdateBarcodeUseCase(getIt<BarcodeRepository>()),
  );
}

// END GENERATED
