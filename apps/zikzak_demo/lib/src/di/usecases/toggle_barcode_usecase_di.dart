// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/barcode_repository.dart';
import '../../domain/usecases/barcode/toggle_barcode_usecase.dart';

void registerToggleBarcodeUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleBarcodeUseCase>(
    () => ToggleBarcodeUseCase(getIt<BarcodeRepository>()),
  );
}

// END GENERATED
