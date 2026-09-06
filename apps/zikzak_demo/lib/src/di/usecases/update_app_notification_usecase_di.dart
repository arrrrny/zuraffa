// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/app_notification_repository.dart';
import '../../domain/usecases/app_notification/update_app_notification_usecase.dart';

void registerUpdateAppNotificationUseCase(GetIt getIt) {
  getIt.registerLazySingleton<UpdateAppNotificationUseCase>(
    () => UpdateAppNotificationUseCase(getIt<AppNotificationRepository>()),
  );
}

// END GENERATED
