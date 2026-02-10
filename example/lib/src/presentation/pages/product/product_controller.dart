import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/product/product.dart';
import 'product_presenter.dart';
import 'product_state.dart';

class ProductController extends Controller
    with StatefulController<ProductState> {
  ProductController(this._presenter);

  final ProductPresenter _presenter;

  @override
  ProductState createInitialState() {
    return const ProductState();
  }

  Future<void> getProduct(String id, [CancelToken? cancelToken = null]) async {
    final token = cancelToken ?? createCancelToken();
    updateState(viewState.copyWith(isGetting: true));
    final result = await _presenter.getProduct(id, token);

    result.fold(
      (entity) =>
          updateState(viewState.copyWith(isGetting: false, product: entity)),
      (failure) =>
          updateState(viewState.copyWith(isGetting: false, error: failure)),
    );
  }

  Future<void> getProductList([
    ListQueryParams<Product> params = const ListQueryParams(),
    CancelToken? cancelToken = null,
  ]) async {
    final token = cancelToken ?? createCancelToken();
    updateState(viewState.copyWith(isGettingList: true));
    final result = await _presenter.getProductList(params, token);

    result.fold(
      (list) => updateState(
        viewState.copyWith(isGettingList: false, productList: list),
      ),
      (failure) =>
          updateState(viewState.copyWith(isGettingList: false, error: failure)),
    );
  }

  Future<void> createProduct(
    Product product, [
    CancelToken? cancelToken = null,
  ]) async {
    final token = cancelToken ?? createCancelToken();
    updateState(viewState.copyWith(isCreating: true));
    final result = await _presenter.createProduct(product, token);

    result.fold(
      (created) => updateState(viewState.copyWith(isCreating: false)),
      (failure) =>
          updateState(viewState.copyWith(isCreating: false, error: failure)),
    );
  }

  Future<void> updateProduct(
    String id,
    ProductPatch data, [
    CancelToken? cancelToken = null,
  ]) async {
    final token = cancelToken ?? createCancelToken();
    updateState(viewState.copyWith(isUpdating: true));
    final result = await _presenter.updateProduct(id, data, token);

    result.fold(
      (updated) => updateState(
        viewState.copyWith(
          isUpdating: false,
          product:
              viewState.product?.id == updated.id ? updated : viewState.product,
        ),
      ),
      (failure) =>
          updateState(viewState.copyWith(isUpdating: false, error: failure)),
    );
  }

  Future<void> deleteProduct(
    String id, [
    CancelToken? cancelToken = null,
  ]) async {
    final token = cancelToken ?? createCancelToken();
    updateState(
      viewState.copyWith(
        isDeleting: true,
        productList: viewState.productList.where((e) => e.id != id).toList(),
      ),
    );

    final result = await _presenter.deleteProduct(id, token);

    result.fold(
      (_) => updateState(viewState.copyWith(isDeleting: false)),
      (failure) =>
          updateState(viewState.copyWith(isDeleting: false, error: failure)),
    );
  }

  void watchProduct(String id, [CancelToken? cancelToken = null]) {
    final token = cancelToken ?? createCancelToken();
    updateState(viewState.copyWith(isWatching: true));
    final subscription = _presenter.watchProduct(id, token).listen((result) {
      result.fold(
        (entity) =>
            updateState(viewState.copyWith(isWatching: false, product: entity)),
        (failure) =>
            updateState(viewState.copyWith(isWatching: false, error: failure)),
      );
    });
    registerSubscription(subscription);
  }

  void watchProductList([
    ListQueryParams<Product> params = const ListQueryParams(),
    CancelToken? cancelToken = null,
  ]) {
    final token = cancelToken ?? createCancelToken();
    updateState(viewState.copyWith(isWatchingList: true));
    final subscription = _presenter.watchProductList(params, token).listen((
      result,
    ) {
      result.fold(
        (list) => updateState(
          viewState.copyWith(isWatchingList: false, productList: list),
        ),
        (failure) => updateState(
          viewState.copyWith(isWatchingList: false, error: failure),
        ),
      );
    });
    registerSubscription(subscription);
  }

  @override
  void onDisposed() {
    _presenter.dispose();
    super.onDisposed();
  }
}
