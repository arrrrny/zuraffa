import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/product/product.dart';
import 'product_data_source.dart';

class ProductLocalDataSource
    with Loggable, FailureHandler
    implements ProductDataSource {
  ProductLocalDataSource(this._box);

  final Box<Product> _box;

  Future<Product> save(Product product) async {
    await _box.put(product.id, product);
    return product;
  }

  Future<void> saveAll(List<Product> items) async {
    final map = {for (var item in items) item.id: item};
    await _box.putAll(map);
  }

  Future<void> clear() async {
    await _box.clear();
  }

  @override
  Future<Product> get(QueryParams<Product> params) async {
    return _box.values.query(params);
  }

  @override
  Future<List<Product>> getList(ListQueryParams<Product> params) async {
    return _box.values.filter(params.filter).orderBy(params.sort);
  }

  @override
  Future<Product> create(Product product) async {
    await _box.put(product.id, product);
    return product;
  }

  @override
  Future<Product> update(UpdateParams<String, ProductPatch> params) async {
    final existing = _box.values.firstWhere(
      (item) => item.id == params.id,
      orElse: () => throw notFoundFailure('Product not found in cache'),
    );
    final updated = params.data.applyTo(existing);
    await _box.put(updated.id, updated);
    return updated;
  }

  @override
  Future<void> delete(DeleteParams<String> params) async {
    final existing = _box.values.firstWhere(
      (item) => item.id == params.id,
      orElse: () => throw notFoundFailure('Product not found in cache'),
    );
    await _box.delete(existing.id);
  }

  @override
  Stream<Product> watch(QueryParams<Product> params) async* {
    yield _box.values.query(params);
  }

  @override
  Stream<List<Product>> watchList(ListQueryParams<Product> params) async* {
    final existing = _box.values.filter(params.filter).orderBy(params.sort);
    yield existing;
    yield* _box.watch().map(
      (_) => _box.values.filter(params.filter).orderBy(params.sort),
    );
  }
}
