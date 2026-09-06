// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/price_drop_notification_repository.dart';
import '../../domain/usecases/price_drop_notification/update_price_drop_notification_usecase.dart';

void registerUpdatePriceDropNotificationUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdatePriceDropNotificationUseCase>(
    () => UpdatePriceDropNotificationUseCase(
      getIt<PriceDropNotificationRepository>(),
    ),
  );
}

// END GENERATED
