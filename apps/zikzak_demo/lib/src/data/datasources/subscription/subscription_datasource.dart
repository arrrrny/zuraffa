// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/subscription/subscription.dart';

abstract class SubscriptionDataSource with Loggable, FailureHandler {
  Future<Subscription> get(QueryParams<Subscription> params);
  Future<Subscription> update(UpdateParams<String, SubscriptionPatch> params);
  Future<Subscription> toggle(
    ToggleParams<String, Field<Subscription, dynamic>> params,
  );
}

// END GENERATED
