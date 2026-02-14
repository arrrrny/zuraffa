import 'package:zuraffa/zuraffa.dart';

import '../entities/product/product.dart';

abstract class ProductRepository {
  Future<Product> get(QueryParams<Product> params);
  Future<List<Product>> getList(ListQueryParams<Product> params);
}
