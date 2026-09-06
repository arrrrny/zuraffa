// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/store_price_repository.dart';
import '../../domain/usecases/store_price/get_store_price_usecase.dart';

void registerGetStorePriceUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetStorePriceUseCase>(
    () => GetStorePriceUseCase(getIt<StorePriceRepository>()),
  );
}

// END GENERATED
