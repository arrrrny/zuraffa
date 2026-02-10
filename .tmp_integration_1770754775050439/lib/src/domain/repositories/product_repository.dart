import 'package:zuraffa/zuraffa.dart';

import '../entities/product/product.dart';

abstract class ProductRepository {
  Future<Product> get(QueryParams<Product> params);
  Future<List<Product>> getList(ListQueryParams<Product> params);
  Future<Product> create(Product product);
  Future<Product> update(UpdateParams<String, Partial<Product>> params);
  Future<void> delete(DeleteParams<String> params);
  Stream<List<Product>> watchList(ListQueryParams<Product> params);
}
