// GENERATED - DO NOT EDIT
import 'package:zuraffa_flutter/zuraffa_flutter.dart';

import '../../../domain/entities/grocery_product/grocery_product.dart';
import 'grocery_product_presenter.dart';
import 'grocery_product_state.dart';

class GroceryProductController extends Controller
    with StatefulController<GroceryProductState> {
  GroceryProductController(this._presenter, {this.initialGroceryProduct});

  final GroceryProductPresenter _presenter;

  final GroceryProduct? initialGroceryProduct;

  @override
  GroceryProductState createInitialState() {
    return GroceryProductState(groceryProduct: initialGroceryProduct);
  }

  Future<void> getGroceryProduct(String id, [CancelToken? cancelToken]) async {
    updateState(viewState.copyWith(isGetting: true));
    final result = await _presenter.getGroceryProduct(id, cancelToken);
    result.fold(
      (entity) {
        updateState(
          viewState.copyWith(isGetting: false, groceryProduct: entity),
        );
      },
      (failure) {
        updateState(viewState.copyWith(isGetting: false, error: failure));
      },
    );
  }

  Future<void> updateGroceryProduct(
    String id,
    GroceryProductPatch data, [
    CancelToken? cancelToken,
  ]) async {
    updateState(viewState.copyWith(isUpdating: true));
    final result = await _presenter.updateGroceryProduct(id, data, cancelToken);
    result.fold(
      (updated) {
        updateState(
          viewState.copyWith(
            isUpdating: false,
            groceryProduct: viewState.groceryProduct?.id == updated.id
                ? updated
                : viewState.groceryProduct,
          ),
        );
      },
      (failure) {
        updateState(viewState.copyWith(isUpdating: false, error: failure));
      },
    );
  }

  Future<void> toggleGroceryProduct(
    String id,
    Field<GroceryProduct, dynamic> field,
    bool toggleValue, [
    CancelToken? cancelToken,
  ]) async {
    updateState(viewState.copyWith(isToggling: true));
    final result = await _presenter.toggleGroceryProduct(
      id,
      field,
      toggleValue,
      cancelToken,
    );
    result.fold(
      (toggled) {
        updateState(
          viewState.copyWith(
            isToggling: false,
            groceryProduct: viewState.groceryProduct?.id == toggled.id
                ? toggled
                : viewState.groceryProduct,
          ),
        );
      },
      (failure) {
        updateState(viewState.copyWith(isToggling: false, error: failure));
      },
    );
  }

  @override
  void onDisposed() {
    _presenter.dispose();
    super.onDisposed();
  }
}

// END GENERATED
