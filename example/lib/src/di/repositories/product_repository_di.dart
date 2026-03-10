import 'package:get_it/get_it.dart';

import '../../cache/daily_cache_policy.dart';
import '../../data/datasources/product/product_local_datasource.dart';
import '../../data/datasources/product/product_remote_datasource.dart';
import '../../data/repositories/data_product_repository.dart';
import '../../domain/repositories/product_repository.dart';

void registerProductRepository(GetIt getIt) {
  getIt.registerLazySingleton<ProductRepository>(
    () => DataProductRepository(
      getIt<ProductRemoteDataSource>(),
      getIt<ProductLocalDataSource>(),
      createDailyCachePolicy(),
    ),
  );
}
