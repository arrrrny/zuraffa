import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/product/product.dart';
import '../../../domain/repositories/product_repository.dart';
import '../../../domain/usecases/product/create_product_usecase.dart';
import '../../../domain/usecases/product/delete_product_usecase.dart';
import '../../../domain/usecases/product/get_product_list_usecase.dart';
import '../../../domain/usecases/product/get_product_usecase.dart';
import '../../../domain/usecases/product/update_product_usecase.dart';
import '../../../domain/usecases/product/watch_product_list_usecase.dart';
import '../../../domain/usecases/product/watch_product_usecase.dart';

class ProductPresenter extends Presenter {
  ProductPresenter({required this.productRepository}) {
    _getProduct = registerUseCase(GetProductUseCase(productRepository));
    _getProductList = registerUseCase(GetProductListUseCase(productRepository));
    _createProduct = registerUseCase(CreateProductUseCase(productRepository));
    _updateProduct = registerUseCase(UpdateProductUseCase(productRepository));
    _deleteProduct = registerUseCase(DeleteProductUseCase(productRepository));
    _watchProduct = registerUseCase(WatchProductUseCase(productRepository));
    _watchProductList = registerUseCase(
      WatchProductListUseCase(productRepository),
    );
  }

  final ProductRepository productRepository;

  late final GetProductUseCase _getProduct;

  late final GetProductListUseCase _getProductList;

  late final CreateProductUseCase _createProduct;

  late final UpdateProductUseCase _updateProduct;

  late final DeleteProductUseCase _deleteProduct;

  late final WatchProductUseCase _watchProduct;

  late final WatchProductListUseCase _watchProductList;

  Future<Result<Product, AppFailure>> getProduct(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _getProduct.call(
      QueryParams<Product>(filter: Eq(ProductFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Future<Result<List<Product>, AppFailure>> getProductList([
    ListQueryParams<Product> params = const ListQueryParams(),
    CancelToken? cancelToken,
  ]) {
    return _getProductList.call(params, cancelToken: cancelToken);
  }

  Future<Result<Product, AppFailure>> createProduct(
    Product product, [
    CancelToken? cancelToken,
  ]) {
    return _createProduct.call(product, cancelToken: cancelToken);
  }

  Future<Result<Product, AppFailure>> updateProduct(
    String id,
    ProductPatch data, [
    CancelToken? cancelToken,
  ]) {
    return _updateProduct.call(
      UpdateParams<String, ProductPatch>(id: id, data: data),
      cancelToken: cancelToken,
    );
  }

  Future<Result<void, AppFailure>> deleteProduct(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _deleteProduct.call(
      DeleteParams<String>(id: id),
      cancelToken: cancelToken,
    );
  }

  Stream<Result<Product, AppFailure>> watchProduct(
    String id, [
    CancelToken? cancelToken,
  ]) {
    return _watchProduct.call(
      QueryParams<Product>(filter: Eq(ProductFields.id, id)),
      cancelToken: cancelToken,
    );
  }

  Stream<Result<List<Product>, AppFailure>> watchProductList([
    ListQueryParams<Product> params = const ListQueryParams(),
    CancelToken? cancelToken,
  ]) {
    return _watchProductList.call(params, cancelToken: cancelToken);
  }
}
