// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/app_notification/app_notification.dart';

abstract class AppNotificationDataSource with Loggable, FailureHandler {
  Future<AppNotification> get(QueryParams<AppNotification> params);
  Future<AppNotification> update(
    UpdateParams<String, AppNotificationPatch> params,
  );
  Future<AppNotification> toggle(
    ToggleParams<String, Field<AppNotification, dynamic>> params,
  );
}

// END GENERATED
