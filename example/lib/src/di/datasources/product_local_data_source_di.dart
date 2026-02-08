// Auto-generated DI registration for ProductLocalDataSource
import 'package:get_it/get_it.dart';
import '../../data/data_sources/product/product_local_data_source.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../../domain/entities/product/product.dart';

void registerProductLocalDataSource(GetIt getIt) {
  getIt.registerLazySingleton<ProductLocalDataSource>(
    () => ProductLocalDataSource(Hive.box<Product>('products')),
  );
}
