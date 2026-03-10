import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/product/product.dart';

abstract class ProductDataSource with Loggable, FailureHandler {
  Future<Product> get(QueryParams<Product> params) {
    throw UnimplementedError();
  }

  Future<List<Product>> getList(ListQueryParams<Product> params) {
    throw UnimplementedError();
  }
}
