// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/price_alert/price_alert_remote_datasource.dart';
import '../../data/repositories/data_price_alert_repository.dart';
import '../../domain/repositories/price_alert_repository.dart';

void registerPriceAlertRepository(GetIt getIt) {
  getIt.registerLazySingleton<PriceAlertRepository>(
    () => DataPriceAlertRepository(getIt<PriceAlertRemoteDataSource>()),
  );
}

// END GENERATED
