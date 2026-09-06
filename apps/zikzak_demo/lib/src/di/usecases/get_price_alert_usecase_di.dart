// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/price_alert_repository.dart';
import '../../domain/usecases/price_alert/get_price_alert_usecase.dart';

void registerGetPriceAlertUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetPriceAlertUseCase>(
    () => GetPriceAlertUseCase(getIt<PriceAlertRepository>()),
  );
}

// END GENERATED
