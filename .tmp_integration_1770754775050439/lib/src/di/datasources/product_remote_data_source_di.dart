import 'package:get_it/get_it.dart';

import '../../data/data_sources/product/product_remote_data_source.dart';

void registerProductRemoteDataSource(GetIt getIt) {
  getIt.registerLazySingleton<ProductRemoteDataSource>(
    () => ProductRemoteDataSource(),
  );
}
