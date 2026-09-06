// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/price_alert/price_alert.dart';
import 'price_alert_datasource.dart';

class PriceAlertRemoteDataSource
    with Loggable, FailureHandler
    implements PriceAlertDataSource {
  @override
  Future<PriceAlert> get(QueryParams<PriceAlert> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<PriceAlert> update(
    UpdateParams<String, PriceAlertPatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<PriceAlert> toggle(
    ToggleParams<String, Field<PriceAlert, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
