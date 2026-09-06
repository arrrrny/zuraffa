// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/grocery_store/grocery_store.dart';
import '../../../domain/usecases/grocery_store/get_grocery_store_usecase.dart';
import '../../../domain/usecases/grocery_store/toggle_grocery_store_usecase.dart';
import '../../../domain/usecases/grocery_store/update_grocery_store_usecase.dart';

class GroceryStorePresenter extends Presenter {
  GroceryStorePresenter() {
    _getGroceryStore = registerUseCase(getIt<GetGroceryStoreUseCase>());
    _updateGroceryStore = registerUseCase(getIt<UpdateGroceryStoreUseCase>());
    _toggleGroceryStore = registerUseCase(getIt<ToggleGroceryStoreUseCase>());
  }

  late final GetGroceryStoreUseCase _getGroceryStore;

  late final UpdateGroceryStoreUseCase _updateGroceryStore;

  late final ToggleGroceryStoreUseCase _toggleGroceryStore;

  Future<Result<GroceryStore, AppFailure>> getGroceryStore(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getGroceryStore.call(
      QueryParams<GroceryStore>(filter: Eq(GroceryStoreFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<GroceryStore, AppFailure>> updateGroceryStore(
    String id,
    GroceryStorePatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateGroceryStore.call(
      UpdateParams<String, GroceryStorePatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<GroceryStore, AppFailure>> toggleGroceryStore(
    String id,
    Field<GroceryStore, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleGroceryStore.call(
      ToggleParams<String, Field<GroceryStore, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
