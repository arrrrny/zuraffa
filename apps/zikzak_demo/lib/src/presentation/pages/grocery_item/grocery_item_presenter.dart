// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../di/service_locator.dart';
import '../../../domain/entities/grocery_item/grocery_item.dart';
import '../../../domain/usecases/grocery_item/get_grocery_item_usecase.dart';
import '../../../domain/usecases/grocery_item/toggle_grocery_item_usecase.dart';
import '../../../domain/usecases/grocery_item/update_grocery_item_usecase.dart';

class GroceryItemPresenter extends Presenter {
  GroceryItemPresenter() {
    _getGroceryItem = registerUseCase(getIt<GetGroceryItemUseCase>());
    _updateGroceryItem = registerUseCase(getIt<UpdateGroceryItemUseCase>());
    _toggleGroceryItem = registerUseCase(getIt<ToggleGroceryItemUseCase>());
  }

  late final GetGroceryItemUseCase _getGroceryItem;

  late final UpdateGroceryItemUseCase _updateGroceryItem;

  late final ToggleGroceryItemUseCase _toggleGroceryItem;

  Future<Result<GroceryItem, AppFailure>> getGroceryItem(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getGroceryItem.call(
      QueryParams<GroceryItem>(filter: Eq(GroceryItemFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<GroceryItem, AppFailure>> updateGroceryItem(
    String id,
    GroceryItemPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateGroceryItem.call(
      UpdateParams<String, GroceryItemPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<GroceryItem, AppFailure>> toggleGroceryItem(
    String id,
    Field<GroceryItem, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) {
    return _toggleGroceryItem.call(
      ToggleParams<String, Field<GroceryItem, dynamic>>(
        id: id,
        field: field,
        value: toggleValue,
      ),
      cancelToken: cancelToken,
    );
  }
}

// END GENERATED
