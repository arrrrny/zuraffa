import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/product/product.dart';
import 'product_datasource.dart';

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
}
