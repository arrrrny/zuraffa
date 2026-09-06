// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/store_price/store_price.dart';
import '../../../domain/usecases/store_price/get_store_price_usecase.dart';
import '../../../domain/usecases/store_price/toggle_store_price_usecase.dart';
import '../../../domain/usecases/store_price/update_store_price_usecase.dart';

class StorePricePresenter extends Presenter {
  StorePricePresenter() {
    _getStorePrice = registerUseCase(getIt<GetStorePriceUseCase>());
    _updateStorePrice = registerUseCase(getIt<UpdateStorePriceUseCase>());
    _toggleStorePrice = registerUseCase(getIt<ToggleStorePriceUseCase>());
  }

  late final GetStorePriceUseCase _getStorePrice;

  late final UpdateStorePriceUseCase _updateStorePrice;

  late final ToggleStorePriceUseCase _toggleStorePrice;

  Future<Result<StorePrice, AppFailure>> getStorePrice(
    String depotId, [
    CancelToken? cancelToken,
  ]) {
    return _getStorePrice.call(
      QueryParams<StorePrice>(filter: Eq(StorePriceFields.depotId, depotId)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<StorePrice, AppFailure>> updateStorePrice(
    String depotId,
    StorePricePatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateStorePrice.call(
      UpdateParams<String, StorePricePatch>(id: depotId, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<StorePrice, AppFailure>> toggleStorePrice(
    String depotId,
    Field<StorePrice, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleStorePrice.call(
      ToggleParams<String, Field<StorePrice, dynamic>>(
        id: depotId,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
