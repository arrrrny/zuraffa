import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/product/product.dart';
import 'product_data_source.dart';

class ProductRemoteDataSource
    with Loggable, FailureHandler
    implements ProductDataSource {
  @override
  Future<Product> get(QueryParams<Product> params) async {
    throw UnimplementedError('Implement remote get');
  }

  @override
  Future<List<Product>> getList(ListQueryParams<Product> params) async {
    throw UnimplementedError('Implement remote getList');
  }

  @override
  Future<Product> create(Product product) async {
    throw UnimplementedError('Implement remote create');
  }

  @override
  Future<Product> update(UpdateParams<String, Partial<Product>> params) async {
    throw UnimplementedError('Implement remote update');
  }

  @override
  Future<void> delete(DeleteParams<String> params) async {
    throw UnimplementedError('Implement remote delete');
  }

  @override
  Stream<List<Product>> watchList(ListQueryParams<Product> params) {
    throw UnimplementedError('Implement remote watchList');
  }
}
