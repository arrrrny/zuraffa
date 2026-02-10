import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/product/product.dart';

abstract class ProductDataSource with Loggable, FailureHandler {
  Future<Product> get(QueryParams<Product> params) {
    throw UnimplementedError();
  }

  Future<List<Product>> getList(ListQueryParams<Product> params) {
    throw UnimplementedError();
  }

  Future<Product> create(Product product) {
    throw UnimplementedError();
  }

  Future<Product> update(UpdateParams<String, Partial<Product>> params) {
    throw UnimplementedError();
  }

  Future<void> delete(DeleteParams<String> params) {
    throw UnimplementedError();
  }

  Stream<List<Product>> watchList(ListQueryParams<Product> params) {
    throw UnimplementedError();
  }
}
