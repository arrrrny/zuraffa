// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/nearby_grocery_store/nearby_grocery_store.dart';
import '../../../domain/usecases/nearby_grocery_store/get_nearby_grocery_store_usecase.dart';
import '../../../domain/usecases/nearby_grocery_store/toggle_nearby_grocery_store_usecase.dart';
import '../../../domain/usecases/nearby_grocery_store/update_nearby_grocery_store_usecase.dart';

class NearbyGroceryStorePresenter extends Presenter {
  NearbyGroceryStorePresenter() {
    _getNearbyGroceryStore = registerUseCase(
      getIt<GetNearbyGroceryStoreUseCase>(),
    );
    _updateNearbyGroceryStore = registerUseCase(
      getIt<UpdateNearbyGroceryStoreUseCase>(),
    );
    _toggleNearbyGroceryStore = registerUseCase(
      getIt<ToggleNearbyGroceryStoreUseCase>(),
    );
  }

  late final GetNearbyGroceryStoreUseCase _getNearbyGroceryStore;

  late final UpdateNearbyGroceryStoreUseCase _updateNearbyGroceryStore;

  late final ToggleNearbyGroceryStoreUseCase _toggleNearbyGroceryStore;

  Future<Result<NearbyGroceryStore, AppFailure>> getNearbyGroceryStore(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getNearbyGroceryStore.call(
      QueryParams<NearbyGroceryStore>(
        filter: Eq(NearbyGroceryStoreFields.id, id),
      ),
      cancelToken: cancelToken,
    );
  }

  Future<Result<NearbyGroceryStore, AppFailure>> updateNearbyGroceryStore(
    String id,
    NearbyGroceryStorePatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateNearbyGroceryStore.call(
      UpdateParams<String, NearbyGroceryStorePatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<NearbyGroceryStore, AppFailure>> toggleNearbyGroceryStore(
    String id,
    Field<NearbyGroceryStore, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleNearbyGroceryStore.call(
      ToggleParams<String, Field<NearbyGroceryStore, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
