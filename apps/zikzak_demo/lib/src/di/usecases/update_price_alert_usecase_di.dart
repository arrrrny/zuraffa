// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/price_alert_repository.dart';
import '../../domain/usecases/price_alert/update_price_alert_usecase.dart';

void registerUpdatePriceAlertUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdatePriceAlertUseCase>(
    () => UpdatePriceAlertUseCase(getIt<PriceAlertRepository>()),
  );
}

// END GENERATED
