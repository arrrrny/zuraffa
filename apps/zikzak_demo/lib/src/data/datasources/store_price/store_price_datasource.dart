// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/store_price/store_price.dart';

abstract class StorePriceDataSource with Loggable, FailureHandler {
  Future<StorePrice> get(QueryParams<StorePrice> params);
  Future<StorePrice> update(UpdateParams<String, StorePricePatch> params);
  Future<StorePrice> toggle(
    ToggleParams<String, Field<StorePrice, dynamic>> params,
  );
}

// END GENERATED
