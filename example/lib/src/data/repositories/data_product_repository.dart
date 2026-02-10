import 'dart:async';

import 'package:zuraffa/zuraffa.dart';

import '../../domain/entities/product/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../data_sources/product/product_data_source.dart';
import '../data_sources/product/product_local_data_source.dart';

class DataProductRepository
    with Loggable, FailureHandler
    implements ProductRepository {
  DataProductRepository(
    this._remoteDataSource,
    this._localDataSource,
    this._cachePolicy,
  );

  final ProductDataSource _remoteDataSource;

  final ProductLocalDataSource _localDataSource;

  final CachePolicy _cachePolicy;

  @override
  Future<Product> get(QueryParams<Product> params) async {
    if (await _cachePolicy.isValid('product_cache')) {
      try {
        return await _localDataSource.get(params);
      } catch (_) {}
    }
    final data = await _remoteDataSource.get(params);
    await _localDataSource.save(data);
    await _cachePolicy.markFresh('product_cache');
    return data;
  }

  @override
  Future<List<Product>> getList(ListQueryParams<Product> params) async {
    final listCacheKey = 'product_cache_${params.hashCode}';
    if (await _cachePolicy.isValid(listCacheKey)) {
      try {
        return await _localDataSource.getList(params);
      } catch (_) {}
    }
    final data = await _remoteDataSource.getList(params);
    await _localDataSource.saveAll(data);
    await _cachePolicy.markFresh(listCacheKey);
    return data;
  }

  @override
  Future<Product> create(Product product) async {
    final data = await _remoteDataSource.create(product);
    await _localDataSource.save(data);
    await _cachePolicy.invalidate('product_cache');
    return data;
  }

  @override
  Future<Product> update(UpdateParams<String, ProductPatch> params) async {
    final data = await _remoteDataSource.update(params);
    await _localDataSource.save(data);
    await _cachePolicy.invalidate('product_cache');
    return data;
  }

  @override
  Future<void> delete(DeleteParams<String> params) async {
    await _remoteDataSource.delete(params);
    await _localDataSource.delete(params);
    await _cachePolicy.invalidate('product_cache');
  }

  @override
  Stream<Product> watch(QueryParams<Product> params) {
    return _remoteDataSource.watch(params);
  }

  @override
  Stream<List<Product>> watchList(ListQueryParams<Product> params) {
    return _remoteDataSource.watchList(params);
  }
}
