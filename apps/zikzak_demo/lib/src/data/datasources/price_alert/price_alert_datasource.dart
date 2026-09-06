// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/price_alert/price_alert.dart';

abstract class PriceAlertDataSource with Loggable, FailureHandler {
  Future<PriceAlert> get(QueryParams<PriceAlert> params);
  Future<PriceAlert> update(UpdateParams<String, PriceAlertPatch> params);
  Future<PriceAlert> toggle(
    ToggleParams<String, Field<PriceAlert, dynamic>> params,
  );
}

// END GENERATED
