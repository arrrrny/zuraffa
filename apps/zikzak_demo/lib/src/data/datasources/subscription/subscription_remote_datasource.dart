// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/subscription/subscription.dart';
import 'subscription_datasource.dart';

class SubscriptionRemoteDataSource
    with Loggable, FailureHandler
    implements SubscriptionDataSource {
  @override
  Future<Subscription> get(QueryParams<Subscription> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<Subscription> update(
    UpdateParams<String, SubscriptionPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<Subscription> toggle(
    ToggleParams<String, Field<Subscription, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
