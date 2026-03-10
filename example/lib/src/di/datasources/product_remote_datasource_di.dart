import 'package:get_it/get_it.dart';

import '../../data/datasources/product/product_remote_datasource.dart';

void registerProductRemoteDataSource(GetIt getIt) {
  getIt.registerLazySingleton<ProductRemoteDataSource>(
    () => ProductRemoteDataSource(),
  );
}
