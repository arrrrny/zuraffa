// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../domain/repositories/app_notification_repository.dart';
import '../../domain/usecases/app_notification/toggle_app_notification_usecase.dart';

void registerToggleAppNotificationUseCase(GetIt getIt) {
  getIt.registerLazySingleton<ToggleAppNotificationUseCase>(
    () => ToggleAppNotificationUseCase(getIt<AppNotificationRepository>()),
  );
}

// END GENERATED
