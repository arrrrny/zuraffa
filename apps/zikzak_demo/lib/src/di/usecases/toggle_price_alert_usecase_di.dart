// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/price_alert_repository.dart';
import '../../domain/usecases/price_alert/toggle_price_alert_usecase.dart';

void registerTogglePriceAlertUseCase(GetIt getIt) {
  getIt.registerLazySingleton<TogglePriceAlertUseCase>(
    () => TogglePriceAlertUseCase(getIt<PriceAlertRepository>()),
  );
}

// END GENERATED
