/// DI registration for ProductRepository (fixture for spec 043).
library;

import 'package:get_it/get_it.dart';

import '../../data/datasources/product_remote_datasource.dart';
import '../../data/repositories/data_product_repository.dart';
import '../../domain/repositories/product_repository.dart';

/// Registers [ProductRepository] bound to its data-layer implementation.
void registerProductRepository(GetIt getIt) {
  getIt.registerLazySingleton<ProductRepository>(
    () => DataProductRepository(ProductRemoteDataSource()),
  );
}
