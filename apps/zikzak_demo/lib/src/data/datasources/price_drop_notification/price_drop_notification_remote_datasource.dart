// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/price_drop_notification/price_drop_notification.dart';
import 'price_drop_notification_datasource.dart';

class PriceDropNotificationRemoteDataSource
    with Loggable, FailureHandler
    implements PriceDropNotificationDataSource {
  @override
  Future<PriceDropNotification> get(
    QueryParams<PriceDropNotification> params,
  ) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<PriceDropNotification> update(
    UpdateParams<String, PriceDropNotificationPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<PriceDropNotification> toggle(
    ToggleParams<String, Field<PriceDropNotification, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
