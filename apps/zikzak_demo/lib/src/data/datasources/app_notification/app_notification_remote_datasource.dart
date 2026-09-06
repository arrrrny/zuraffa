// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/app_notification/app_notification.dart';
import 'app_notification_datasource.dart';

class AppNotificationRemoteDataSource
    with Loggable, FailureHandler
    implements AppNotificationDataSource {
  @override
  Future<AppNotification> get(QueryParams<AppNotification> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<AppNotification> update(
    UpdateParams<String, AppNotificationPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<AppNotification> toggle(
    ToggleParams<String, Field<AppNotification, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
