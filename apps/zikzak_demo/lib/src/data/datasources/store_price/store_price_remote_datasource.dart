// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/store_price/store_price.dart';
import 'store_price_datasource.dart';

class StorePriceRemoteDataSource
    with Loggable, FailureHandler
    implements StorePriceDataSource {
  @override
  Future<StorePrice> get(QueryParams<StorePrice> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<StorePrice> update(
    UpdateParams<String, StorePricePatch> params,
  ) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<StorePrice> toggle(
    ToggleParams<String, Field<StorePrice, dynamic>> params,
  ) async {
    throw UnimplementedError('Implement remote toggle');
  }
}

// END GENERATED
