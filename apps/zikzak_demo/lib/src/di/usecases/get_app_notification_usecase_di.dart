// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/app_notification_repository.dart';
import '../../domain/usecases/app_notification/get_app_notification_usecase.dart';

void registerGetAppNotificationUseCase(GetIt getIt) {
  getIt.registerLazySingleton<GetAppNotificationUseCase>(
    () => GetAppNotificationUseCase(getIt<AppNotificationRepository>()),
  );
}

// END GENERATED
