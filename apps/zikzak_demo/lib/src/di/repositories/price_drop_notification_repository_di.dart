// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/price_drop_notification/price_drop_notification_remote_datasource.dart';
import '../../data/repositories/data_price_drop_notification_repository.dart';
import '../../domain/repositories/price_drop_notification_repository.dart';

void registerPriceDropNotificationRepository(GetIt getIt) {
  getIt.registerLazySingleton<PriceDropNotificationRepository>(
    () => DataPriceDropNotificationRepository(
      getIt<PriceDropNotificationRemoteDataSource>(),
    ),
  );
}

// END GENERATED
