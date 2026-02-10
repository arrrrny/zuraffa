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

  @override
  Future<Product> create(Product product) {
    return _dataSource.create(product);
  }

  @override
  Future<Product> update(UpdateParams<String, Partial<Product>> params) {
    return _dataSource.update(params);
  }

  @override
  Future<void> delete(DeleteParams<String> params) {
    return _dataSource.delete(params);
  }

  @override
  Stream<List<Product>> watchList(ListQueryParams<Product> params) {
    return _dataSource.watchList(params);
  }
}
