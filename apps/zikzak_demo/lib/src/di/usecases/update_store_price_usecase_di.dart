// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/store_price_repository.dart';
import '../../domain/usecases/store_price/update_store_price_usecase.dart';

void registerUpdateStorePriceUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateStorePriceUseCase>(
    () => UpdateStorePriceUseCase(getIt<StorePriceRepository>()),
  );
}

// END GENERATED
