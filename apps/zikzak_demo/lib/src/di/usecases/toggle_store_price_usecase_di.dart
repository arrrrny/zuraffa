// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/store_price_repository.dart';
import '../../domain/usecases/store_price/toggle_store_price_usecase.dart';

void registerToggleStorePriceUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleStorePriceUseCase>(
    () => ToggleStorePriceUseCase(getIt<StorePriceRepository>()),
  );
}

// END GENERATED
