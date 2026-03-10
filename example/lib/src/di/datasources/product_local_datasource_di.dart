import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../data/datasources/product/product_local_datasource.dart';
import '../../domain/entities/product/product.dart';

void registerProductLocalDataSource(GetIt getIt) {
  getIt.registerLazySingleton<ProductLocalDataSource>(
    () => ProductLocalDataSource(Hive.box<Product>('products')),
  );
}
