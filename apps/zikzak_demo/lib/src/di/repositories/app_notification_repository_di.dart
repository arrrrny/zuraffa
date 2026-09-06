// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../data/datasources/app_notification/app_notification_remote_datasource.dart';
import '../../data/repositories/data_app_notification_repository.dart';
import '../../domain/repositories/app_notification_repository.dart';

void registerAppNotificationRepository(GetIt getIt) {
  getIt.registerLazySingleton<AppNotificationRepository>(
    () =>
        DataAppNotificationRepository(getIt<AppNotificationRemoteDataSource>()),
  );
}

// END GENERATED
