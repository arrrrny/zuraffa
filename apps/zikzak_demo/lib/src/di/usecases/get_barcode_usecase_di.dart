// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/barcode_repository.dart';
import '../../domain/usecases/barcode/get_barcode_usecase.dart';

void registerGetBarcodeUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetBarcodeUseCase>(
    () => GetBarcodeUseCase(getIt<BarcodeRepository>()),
  );
}

// END GENERATED
