import 'package:zuraffa/zuraffa.dart';

import '../../domain/entities/product/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../data_sources/product/product_data_source.dart';

class DataProductRepository
    with Loggable, FailureHandler
    implements ProductRepository {
  DataProductRepository(this._dataSource);

  final ProductDataSource _dataSource;

  @override
  Future<Product> get(QueryParams<Product> params) {
    return _dataSource.get(params);
  }

  @override
  Future<List<Product>> getList(ListQueryParams<Product> params) {
    return _dataSource.getList(params);
  }
}
