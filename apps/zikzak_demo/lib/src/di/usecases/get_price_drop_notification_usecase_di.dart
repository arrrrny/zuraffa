// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/price_drop_notification_repository.dart';
import '../../domain/usecases/price_drop_notification/get_price_drop_notification_usecase.dart';

void registerGetPriceDropNotificationUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetPriceDropNotificationUseCase>(
    () => GetPriceDropNotificationUseCase(
      getIt<PriceDropNotificationRepository>(),
    ),
  );
}

// END GENERATED
