// Auto-generated DI registration for ProductRepository
import 'package:get_it/get_it.dart';
import '../../domain/repositories/product_repository.dart';
import '../../data/repositories/data_product_repository.dart';
import '../../data/data_sources/product/product_remote_data_source.dart';
import '../../data/data_sources/product/product_local_data_source.dart';
import '../../cache/ttl_5_minutes_cache_policy.dart';

void registerProductRepository(GetIt getIt) {
  getIt.registerLazySingleton<ProductRepository>(
    () => DataProductRepository(
      getIt<ProductRemoteDataSource>(),
      getIt<ProductLocalDataSource>(),
      createTtl5MinutesCachePolicy(),
    ),
  );
}
