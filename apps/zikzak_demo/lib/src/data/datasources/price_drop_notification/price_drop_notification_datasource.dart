// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/price_drop_notification/price_drop_notification.dart';

abstract class PriceDropNotificationDataSource with Loggable, FailureHandler {
  Future<PriceDropNotification> get(QueryParams<PriceDropNotification> params);
  Future<PriceDropNotification> update(
    UpdateParams<String, PriceDropNotificationPatch> params,
  );
  Future<PriceDropNotification> toggle(
    ToggleParams<String, Field<PriceDropNotification, dynamic>> params,
  );
}

// END GENERATED
