// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/grocery_sub_variety/grocery_sub_variety.dart';
import '../../../domain/usecases/grocery_sub_variety/get_grocery_sub_variety_usecase.dart';
import '../../../domain/usecases/grocery_sub_variety/toggle_grocery_sub_variety_usecase.dart';
import '../../../domain/usecases/grocery_sub_variety/update_grocery_sub_variety_usecase.dart';

class GrocerySubVarietyPresenter extends Presenter {
  GrocerySubVarietyPresenter() {
    _getGrocerySubVariety = registerUseCase(
      getIt<GetGrocerySubVarietyUseCase>(),
    );
    _updateGrocerySubVariety = registerUseCase(
      getIt<UpdateGrocerySubVarietyUseCase>(),
    );
    _toggleGrocerySubVariety = registerUseCase(
      getIt<ToggleGrocerySubVarietyUseCase>(),
    );
  }

  late final GetGrocerySubVarietyUseCase _getGrocerySubVariety;

  late final UpdateGrocerySubVarietyUseCase _updateGrocerySubVariety;

  late final ToggleGrocerySubVarietyUseCase _toggleGrocerySubVariety;

  Future<Result<GrocerySubVariety, AppFailure>> getGrocerySubVariety(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getGrocerySubVariety.call(
      QueryParams<GrocerySubVariety>(
        filter: Eq(GrocerySubVarietyFields.id, id),
      ),
      cancelToken: cancelToken,
    );
  }

  Future<Result<GrocerySubVariety, AppFailure>> updateGrocerySubVariety(
    String id,
    GrocerySubVarietyPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateGrocerySubVariety.call(
      UpdateParams<String, GrocerySubVarietyPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<GrocerySubVariety, AppFailure>> toggleGrocerySubVariety(
    String id,
    Field<GrocerySubVariety, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleGrocerySubVariety.call(
      ToggleParams<String, Field<GrocerySubVariety, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
