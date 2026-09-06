// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/price_drop_notification_repository.dart';
import '../../domain/usecases/price_drop_notification/toggle_price_drop_notification_usecase.dart';

void registerTogglePriceDropNotificationUseCase(GetIt getIt) {
  getIt.registerLazySingleton<TogglePriceDropNotificationUseCase>(
    () => TogglePriceDropNotificationUseCase(
      getIt<PriceDropNotificationRepository>(),
    ),
  );
}

// END GENERATED
